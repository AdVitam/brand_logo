# frozen_string_literal: true
# typed: strict

require 'http'
require 'uri'

module BrandLogo
  module Http
    class Session
      extend T::Sig
      include Client

      ACCEPT = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/*;q=0.8,*/*;q=0.5'
      ACCEPT_LANGUAGE = 'en;q=0.8,*;q=0.5'
      # http 5 parses URLs with Addressable, http 6 (which drops it) raises an HTTP::Error.
      NETWORK_ERRORS = T.let([
        HTTP::Error, OpenSSL::SSL::SSLError, SocketError, IOError, SystemCallError, Timeout::Error, URI::Error,
        *(Addressable::URI::InvalidURIError if defined?(Addressable::URI::InvalidURIError))
      ].freeze, T::Array[T.class_of(Exception)])
      STALE_ERRORS = T.let(
        [HTTP::ConnectionError, IOError, Errno::ECONNRESET, Errno::EPIPE].freeze, T::Array[T.class_of(Exception)]
      )
      REDIRECT_STATUSES = T.let([301, 302, 303, 307, 308].freeze, T::Array[Integer])

      sig { params(config: Config).void }
      def initialize(config)
        @config = config
        @mutex = T.let(Mutex.new, Mutex)
        @sockets = T.let({}, T::Hash[String, T.nilable(T.class_of(TCPSocket))])
        @pool = T.let(ConnectionPool.new(config.timeout), ConnectionPool)
      end

      sig { void }
      def close
        @pool.close
      end

      sig do
        override.params(
          url: String,
          deadline: Deadline,
          max_bytes: Integer,
          range: T.nilable(T::Range[Integer])
        ).returns(T.nilable(Response))
      end
      def get(url, deadline:, max_bytes:, range: nil)
        current = url
        (@config.max_hops + 1).times do
          return nil if deadline.expired?

          result = request(current, deadline, max_bytes, range)
          return result if result.nil? || result.is_a?(Response)

          current = result
        end
        log("too many redirects for #{url}")
        nil
      rescue *NETWORK_ERRORS => e
        log("#{url}: #{e.class}: #{e.message}")
        nil
      end

      private

      sig { params(origin: String, url: String).returns(T.nilable(T.class_of(TCPSocket))) }
      def socket_class_for(origin, url)
        @mutex.synchronize { return @sockets[origin] || blocked(url) if @sockets.key?(origin) }

        # Resolved outside the lock so origins resolve in parallel; the first answer wins to keep a single pin.
        resolved = resolve_socket_class(url)
        @mutex.synchronize { @sockets.fetch(origin) { @sockets[origin] = resolved } } || blocked(url)
      end

      sig { params(url: String).returns(T.nilable(T.class_of(TCPSocket))) }
      def resolve_socket_class(url)
        return (UrlGuard.web_url?(url) ? TCPSocket : nil) unless @config.block_private_ips

        addresses = UrlGuard.validated_addresses(url)
        addresses.empty? ? nil : pinned_socket(addresses)
      end

      sig { params(addresses: T::Array[IPAddr]).returns(T.class_of(TCPSocket)) }
      def pinned_socket(addresses)
        Class.new(TCPSocket) do
          define_singleton_method(:open) do |_host, port, **options|
            last_error = T.let(nil, T.nilable(SystemCallError))
            addresses.each do |address|
              return super(address.to_s, port, **options)
            rescue SystemCallError => e
              last_error = e
            end
            raise T.must(last_error)
          end
        end
      end

      sig { params(url: String).returns(NilClass) }
      def blocked(url)
        log("blocked #{url}")
        nil
      end

      sig do
        params(
          url: String, deadline: Deadline, max_bytes: Integer, range: T.nilable(T::Range[Integer])
        ).returns(T.nilable(T.any(Response, String)))
      end
      def request(url, deadline, max_bytes, range)
        origin = HTTP::URI.parse(url).origin
        socket_class = socket_class_for(origin, url)
        return nil unless socket_class

        idle = @pool.take(origin, deadline)
        if idle
          begin
            return exchange(url, origin, idle, max_bytes, range)
          # The server may have dropped an idle keep-alive connection; a GET is safe to replay once.
          rescue *STALE_ERRORS => e
            log("#{url}: reconnecting after #{e.class}")
          end
        end
        exchange(url, origin, @pool.open(origin, socket_class, deadline), max_bytes, range)
      end

      sig do
        params(
          url: String, origin: String, entry: ConnectionPool::Entry, max_bytes: Integer, range: T.nilable(T::Range[Integer])
        ).returns(T.nilable(T.any(Response, String)))
      end
      def exchange(url, origin, entry, max_bytes, range)
        reusable = T.let(false, T::Boolean)
        begin
          response = entry.client.get(url, headers: headers(range))
          status = response.status.to_i
          return redirect_target(url, response) if REDIRECT_STATUSES.include?(status)

          unless response.status.success?
            log("#{url}: HTTP #{status}")
            return nil
          end

          body, reusable = read_body(response, max_bytes)
          Response.new(url: url, body: body)
        ensure
          # Closing instead of reusing: the gem would first drain up to 1 MB of leftover body.
          reusable ? @pool.release(origin, entry) : entry.client.close
        end
      end

      sig { params(url: String, response: HTTP::Response).returns(T.nilable(String)) }
      def redirect_target(url, response)
        location = response.headers['Location']&.to_s
        return nil if location.nil? || location.empty?

        URI.join(url, location).to_s
      end

      sig { params(response: HTTP::Response, max_bytes: Integer).returns([String, T::Boolean]) }
      def read_body(response, max_bytes)
        buffer = String.new(encoding: Encoding::BINARY)
        complete = T.let(true, T::Boolean)
        response.body.each do |chunk|
          buffer << chunk.b
          next if buffer.bytesize < max_bytes

          complete = false
          break
        end
        [buffer.bytesize > max_bytes ? T.must(buffer.byteslice(0, max_bytes)) : buffer, complete]
      end

      sig { params(range: T.nilable(T::Range[Integer])).returns(T::Hash[String, String]) }
      def headers(range)
        base = { 'User-Agent' => @config.user_agent, 'Accept' => ACCEPT, 'Accept-Language' => ACCEPT_LANGUAGE }
        range ? base.merge('Range' => "bytes=#{range.min}-#{range.max}") : base
      end

      sig { params(message: String).void }
      def log(message)
        Logging.logger.debug("[BrandLogo] #{message}")
      end
    end
  end
end
