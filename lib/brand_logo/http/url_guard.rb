# frozen_string_literal: true
# typed: strict

require 'ipaddr'
require 'resolv'
require 'socket'
require 'uri'

module BrandLogo
  module Http
    module UrlGuard
      extend T::Sig

      SCHEMES = T.let(%w[http https].freeze, T::Array[String])
      BLOCKED_RANGES = T.let(
        %w[
          0.0.0.0/8 100.64.0.0/10 192.0.0.0/24 192.0.2.0/24 198.18.0.0/15 198.51.100.0/24
          203.0.113.0/24 224.0.0.0/4 240.0.0.0/4 ::/128 64:ff9b::/96 100::/64 fc00::/7 fe80::/10 ff00::/8
        ].map { |cidr| IPAddr.new(cidr) }.freeze,
        T::Array[IPAddr]
      )

      sig { params(url: String, block_private_ips: T::Boolean).returns(T::Boolean) }
      def self.allowed?(url, block_private_ips:)
        host = web_host(URI.parse(url))
        return false unless host
        return true unless block_private_ips

        addresses = resolve(host)
        !addresses.empty? && addresses.none? { |address| blocked?(address) }
      rescue URI::Error
        false
      end

      sig { params(uri: URI::Generic).returns(T.nilable(String)) }
      def self.web_host(uri)
        host = uri.hostname
        host if SCHEMES.include?(uri.scheme&.downcase) && host && !host.empty?
      end

      sig { params(host: String).returns(T::Array[IPAddr]) }
      def self.resolve(host)
        literal = parse_ip(host)
        return [literal] if literal

        Addrinfo.getaddrinfo(host, nil, nil, :STREAM).filter_map { |info| parse_ip(info.ip_address) }
      rescue SocketError
        []
      end

      sig { params(value: String).returns(T.nilable(IPAddr)) }
      def self.parse_ip(value)
        IPAddr.new(value.sub(/%.*\z/, ''))
      rescue IPAddr::Error
        nil
      end

      sig { params(address: IPAddr).returns(T::Boolean) }
      def self.blocked?(address)
        address = address.native if address.ipv4_mapped?
        address.private? || address.loopback? || address.link_local? ||
          BLOCKED_RANGES.any? { |range| range.family == address.family && range.include?(address) }
      end

      private_class_method :resolve, :parse_ip, :blocked?
    end
  end
end
