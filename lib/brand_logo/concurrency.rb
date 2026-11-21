# frozen_string_literal: true
# typed: strict

module BrandLogo
  module Concurrency
    extend T::Sig

    sig do
      type_parameters(:I, :O)
        .params(
          items: T::Array[T.type_parameter(:I)],
          size: Integer,
          block: T.proc.params(item: T.type_parameter(:I)).returns(T.type_parameter(:O))
        )
        .returns(T::Array[T.type_parameter(:O)])
    end
    def self.map(items, size:, &block)
      return items.map(&block) if items.size <= 1 || size <= 1

      results = T.let(Array.new(items.size), T::Array[T.untyped])
      failures = Queue.new
      queue = Queue.new(items.each_index.to_a).close

      spawn([size, items.size].min) { work(queue, failures) { |index| results[index] = yield(items.fetch(index)) } }
      raise failures.pop unless failures.empty?

      results
    end

    sig do
      type_parameters(:O)
        .params(size: Integer, block: T.proc.returns(T.type_parameter(:O)))
        .returns(T.proc.returns(T.type_parameter(:O)))
    end
    def self.async(size:, &block)
      return block if size <= 1

      thread = start(&block)
      -> { thread.value }
    end

    sig { params(count: Integer, block: T.proc.void).void }
    def self.spawn(count, &block)
      Array.new(count) { start(&block) }.each(&:join)
    end

    sig { type_parameters(:O).params(block: T.proc.returns(T.type_parameter(:O))).returns(Thread) }
    def self.start(&block)
      Thread.new do
        Thread.current.report_on_exception = false
        yield
      end
    end

    sig { params(queue: Thread::Queue, failures: Thread::Queue, block: T.proc.params(index: Integer).void).void }
    def self.work(queue, failures, &block)
      while (index = queue.pop)
        begin
          yield(index)
        rescue StandardError => e
          failures << e
          queue.clear
        end
      end
    end
    private_class_method :spawn, :start, :work
  end
end
