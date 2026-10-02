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
      STAGES.each do |stage|
        break if @context.deadline.expired?
        next if stage == :external && icons.any?

        icons = run(stage, icons)
        winner = icons.first
        return winner if winner && @ranker.good_enough?(winner)
      end
      icons.first
    end

    sig { returns(T::Array[Icon]) }
    def all
      STAGES.reduce(T.let([], T::Array[Icon])) do |icons, stage|
        @context.deadline.expired? ? icons : run(stage, icons)
      end
    end

    sig { returns(T::Boolean) }
    def timed_out?
      @context.deadline.expired?
    end

    private

    sig { params(stage: Symbol, previous: T::Array[Icon]).returns(T::Array[Icon]) }
    def run(stage, previous)
      seen = previous.to_set(&:url)
      candidates = collect(stage).uniq(&:url).reject { |icon| seen.include?(icon.url) }
      BrandLogo::Logging.logger.debug("[#{@context.domain}] #{stage}: #{candidates.size} new candidate(s)")
      @ranker.rank(previous + parallel(candidates) { |icon| measure(icon) }.compact)
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

      icon.with(format: result.format, dimensions: measured_dimensions(icon, result))
    end

    # FastImage reads only the first entry of an .ico, which is often smaller than the declared largest one.
    sig { params(icon: Icon, result: ImageProbe::Result).returns(Dimensions) }
    def measured_dimensions(icon, result)
      measured = result.dimensions
      return icon.dimensions unless measured.known?
      return [measured, icon.dimensions].max_by(&:area) || measured if result.format == :ico

      measured
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
