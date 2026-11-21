# frozen_string_literal: true
# typed: strict

require 'http'

module BrandLogo
  module Http
    class ConnectionPool
      extend T::Sig

      Entry = Data.define(:client, :timeout)

      sig { params(timeout: Numeric).void }
      def initialize(timeout)
        @timeout = timeout
        @mutex = T.let(Mutex.new, Mutex)
        @idle = T.let({}, T::Hash[String, T::Array[Entry]])
      end

      sig { params(origin: String, deadline: Deadline).returns(T.nilable(Entry)) }
      def take(origin, deadline)
        remaining = deadline.remaining
        # A reused connection keeps the timeout it was opened with, so it can only serve a deadline at least as long.
        while (entry = @mutex.synchronize { @idle[origin]&.pop })
          return entry if entry.timeout <= remaining

          entry.client.close
        end
      end

      sig { params(origin: String, socket_class: T.class_of(TCPSocket), deadline: Deadline).returns(Entry) }
      def open(origin, socket_class, deadline)
        timeout = [@timeout, deadline.remaining].min
        client = HTTP::Client.new(
          persistent: origin, socket_class: socket_class,
          timeout_class: HTTP::Timeout::Global, timeout_options: { global_timeout: timeout }
        )
        Entry.new(client: client, timeout: timeout)
      end

      sig { params(origin: String, entry: Entry).void }
      def release(origin, entry)
        @mutex.synchronize { (@idle[origin] ||= []).push(entry) }
      end

      sig { void }
      def close
        entries = @mutex.synchronize { @idle.values.flatten.tap { @idle.clear } }
        entries.each { |entry| entry.client.close }
      end
    end
  end
end
