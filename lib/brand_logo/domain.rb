# frozen_string_literal: true
# typed: strict

require 'uri'

module BrandLogo
  module Domain
    extend T::Sig

    MAX_LENGTH = 253
    LABEL = T.let(/\A[a-z0-9]([a-z0-9-]{0,61}[a-z0-9])?\z/, Regexp)
    TLD = T.let(/\A([a-z]{2,}|xn--[a-z0-9-]+)\z/, Regexp)
    IPV4 = T.let(/\A\d+(\.\d+){3}\z/, Regexp)

    sig { params(input: String).returns(String) }
    def self.normalize(input)
      text = input.strip.downcase
      invalid!(input, 'is empty') if text.empty?
      invalid!(input, 'must be ASCII; use punycode ("xn--...") for internationalized names') unless text.ascii_only?

      host = extract_host(input, text)
      validate!(input, host)
      host
    end

    sig { params(input: String, text: String).returns(String) }
    def self.extract_host(input, text)
      host = if text.include?('://') || text.start_with?('//')
               URI.parse(text).host.to_s
             else
               text.split(%r{[/?#]}, 2).first.to_s
             end
      invalid!(input, 'is an IP address') if host.start_with?('[') || host.count(':') > 1
      host.sub(/:\d*\z/, '').delete_suffix('.')
    rescue URI::InvalidURIError
      invalid!(input, 'is not a valid URL')
    end

    sig { params(input: String, host: String).void }
    def self.validate!(input, host)
      invalid!(input, 'has no hostname') if host.empty?
      invalid!(input, 'is an IP address') if IPV4.match?(host)
      invalid!(input, "is longer than #{MAX_LENGTH} characters") if host.length > MAX_LENGTH

      validate_labels!(input, host.split('.', -1))
    end

    sig { params(input: String, labels: T::Array[String]).void }
    def self.validate_labels!(input, labels)
      invalid!(input, 'must contain a dot (e.g. "example.com")') if labels.length < 2
      unless labels.all? { |label| LABEL.match?(label) }
        invalid!(input, 'has an invalid label (1-63 letters, digits or inner hyphens)')
      end
      invalid!(input, 'has an invalid top-level domain') unless TLD.match?(labels.last.to_s)
    end

    sig { params(input: String, reason: String).returns(T.noreturn) }
    def self.invalid!(input, reason)
      raise ValidationError, "Invalid domain #{input.inspect}: #{reason}"
    end

    private_class_method :extract_host, :validate!, :validate_labels!, :invalid!
  end
end
