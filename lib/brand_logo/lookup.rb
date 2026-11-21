# frozen_string_literal: true
# typed: strict

module BrandLogo
  class Lookup
    extend T::Sig

    STAGES = T.let(%i[document remote external].freeze, T::Array[Symbol])

    sig { params(context: Context, strategies: T::Array[Strategies::Base], ranker: Ranker).void }
    def initialize(context:, strategies:, ranker:)
      @context = context
      @strategies = strategies
      @ranker = ranker
    end

    sig { returns(T.nilable(Icon)) }
    def best
      icons = T.let([], T::Array[Icon])
      collections = start_collections
      STAGES.each do |stage|
        break if @context.deadline.expired?
        next if skip?(stage, icons)

        icons = run(stage, icons, collections.fetch(stage), stop_early: true)
        return icons.first if settled?(icons)
      end
      icons.first
    end

    sig { returns(T::Array[Icon]) }
    def all
      collections = start_collections
      STAGES.reduce(T.let([], T::Array[Icon])) do |icons, stage|
        @context.deadline.expired? ? icons : run(stage, icons, collections.fetch(stage), stop_early: false)
      end
    end

    sig { returns(T::Boolean) }
    def timed_out?
      @context.deadline.expired?
    end

    private

    sig { params(stage: Symbol, icons: T::Array[Icon]).returns(T::Boolean) }
    def skip?(stage, icons)
      stage == :external && icons.any? { |icon| @ranker.usable?(icon) }
    end

    sig { returns(T::Hash[Symbol, T.proc.returns(T::Array[Icon])]) }
    def start_collections
      STAGES.to_h { |stage| [stage, Concurrency.async(size: @context.config.concurrency) { collect(stage) }] }
    end

    sig do
      params(
        stage: Symbol, previous: T::Array[Icon], collection: T.proc.returns(T::Array[Icon]), stop_early: T::Boolean
      ).returns(T::Array[Icon])
    end
    def run(stage, previous, collection, stop_early:)
      seen = previous.to_set(&:url)
      candidates = collection.call.uniq(&:url).reject { |icon| seen.include?(icon.url) }
      BrandLogo::Logging.logger.debug("[#{@context.domain}] #{stage}: #{candidates.size} new candidate(s)")
      batch = stop_early ? @context.config.concurrency : [candidates.size, 1].max
      icons = previous
      @ranker.order(candidates).each_slice(batch) do |slice|
        icons = @ranker.rank(icons + parallel(slice) { |icon| measure(icon) }.compact)
        break if stop_early && settled?(icons)
      end
      icons
    end

    sig { params(icons: T::Array[Icon]).returns(T::Boolean) }
    def settled?(icons)
      winner = icons.first
      (!winner.nil? && @ranker.good_enough?(winner)) || @context.deadline.expired?
    end

    sig { params(stage: Symbol).returns(T::Array[Icon]) }
    def collect(stage)
      strategies = @strategies.select { |strategy| strategy.stage == stage }
      parallel(strategies) { |strategy| strategy.call(@context) }.flatten
    end

    sig { params(icon: Icon).returns(T.nilable(Icon)) }
    def measure(icon)
      result = @context.probe(icon.url)
      return nil unless result

      dimensions = result.dimensions
      icon.with(format: result.format, dimensions: dimensions.known? ? dimensions : icon.dimensions)
    end

    sig do
      type_parameters(:I, :O)
        .params(
          items: T::Array[T.type_parameter(:I)],
          block: T.proc.params(item: T.type_parameter(:I)).returns(T.type_parameter(:O))
        )
        .returns(T::Array[T.type_parameter(:O)])
    end
    def parallel(items, &block)
      Concurrency.map(items, size: @context.config.concurrency, &block)
    end
  end
end
