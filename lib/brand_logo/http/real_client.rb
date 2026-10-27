# frozen_string_literal: true
# typed: strict

require 'http'
require 'uri'

module BrandLogo
  module Http
    class RealClient
      extend T::Sig
      include Client

      ACCEPT = 'text/html,application/xhtml+xml,application/xml;q=0.9,image/*;q=0.8,*/*;q=0.5'
      ACCEPT_LANGUAGE = 'en;q=0.8,*;q=0.5'
      NETWORK_ERRORS = T.let([
        HTTP::Error, OpenSSL::SSL::SSLError, SocketError, IOError, SystemCallError, Timeout::Error, URI::Error
      ].freeze, T::Array[T.class_of(Exception)])
      REDIRECT_STATUSES = T.let([301, 302, 303, 307, 308].freeze, T::Array[Integer])

      sig { params(config: Config).void }
      def initialize(config)
        @config = config
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

          socket_class = socket_class_for(current)
          return nil unless socket_class

          result = request(current, socket_class, deadline, max_bytes, range)
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

      sig { params(url: String).returns(T.nilable(T.class_of(TCPSocket))) }
      def socket_class_for(url)
        return (UrlGuard.web_url?(url) ? TCPSocket : blocked(url)) unless @config.block_private_ips

        address = UrlGuard.resolve(url)
        address ? pinned_socket(address) : blocked(url)
      end

      sig { params(address: IPAddr).returns(T.class_of(TCPSocket)) }
      def pinned_socket(address)
        Class.new(TCPSocket) do
          define_singleton_method(:open) { |_host, port, **options| super(address.to_s, port, **options) }
        end
      end

      sig { params(url: String).returns(NilClass) }
      def blocked(url)
        log("blocked #{url}")
        nil
      end

      sig do
        params(
          url: String, socket_class: T.class_of(TCPSocket), deadline: Deadline, max_bytes: Integer,
          range: T.nilable(T::Range[Integer])
        ).returns(T.nilable(T.any(Response, String)))
      end
      def request(url, socket_class, deadline, max_bytes, range)
        client = HTTP::Client.new(socket_class: socket_class)
                             .timeout([@config.timeout, deadline.remaining].min).headers(headers(range))
        response = client.get(url)
        status = response.status.to_i
        return redirect_target(url, response) if REDIRECT_STATUSES.include?(status)

        unless response.status.success?
          log("#{url}: HTTP #{status}")
          return nil
        end

        Response.new(url: url, body: read_body(response, max_bytes))
      ensure
        client&.close
      end

      sig { params(url: String, response: HTTP::Response).returns(T.nilable(String)) }
      def redirect_target(url, response)
        location = response.headers['Location']&.to_s
        return nil if location.nil? || location.empty?

        URI.join(url, location).to_s
      end

      sig { params(response: HTTP::Response, max_bytes: Integer).returns(String) }
      def read_body(response, max_bytes)
        buffer = String.new(encoding: Encoding::BINARY)
        response.body.each do |chunk|
          buffer << chunk.b
          break if buffer.bytesize >= max_bytes
        end
        buffer.bytesize > max_bytes ? T.must(buffer.byteslice(0, max_bytes)) : buffer
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
