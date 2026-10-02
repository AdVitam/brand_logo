# frozen_string_literal: true

RSpec.describe BrandLogo::Concurrency do
  describe '.map' do
    it 'returns results in input order' do
      result = described_class.map([3, 1, 2], size: 3) do |n|
        sleep(n * 0.01)
        n * 10
      end

      expect(result).to eq([30, 10, 20])
    end

    it 'runs inline without threads for a single item' do
      threads = described_class.map([1], size: 4) { Thread.current }

      expect(threads).to eq([Thread.current])
    end

    it 'runs inline when size is 1' do
      threads = described_class.map([1, 2], size: 1) { Thread.current }

      expect(threads).to eq([Thread.current, Thread.current])
    end

    it 'returns an empty array for no items' do
      expect(described_class.map([], size: 4) { |n| n }).to eq([])
    end

    it 'never exceeds the requested number of threads' do
      active = 0
      peak = 0
      lock = Mutex.new
      described_class.map(Array.new(12) { |i| i }, size: 3) do |n|
        lock.synchronize { peak = [peak, active += 1].max }
        sleep(0.01)
        lock.synchronize { active -= 1 }
        n
      end

      expect(peak).to be_between(1, 3)
    end

    it 'runs items on worker threads' do
      threads = described_class.map([1, 2, 3], size: 3) { Thread.current }

      expect(threads).not_to include(Thread.current)
    end

    it 're-raises the first exception in the caller' do
      expect do
        described_class.map([1, 2, 3, 4], size: 2) { |n| n == 2 ? raise(ArgumentError, 'boom') : n }
      end.to raise_error(ArgumentError, 'boom')
    end

    it 'stops picking new items after a failure' do
      processed = Queue.new
      expect do
        described_class.map(Array.new(50) { |i| i }, size: 2) do |n|
          processed << n
          sleep(0.01)
          raise 'boom' if n.zero?

          n
        end
      end.to raise_error(RuntimeError, 'boom')

      expect(processed.size).to be < 50
    end

    it 'does not print worker exceptions' do
      expect do
        described_class.map([1, 2], size: 2) { |item| raise 'quiet' if item.positive? }
      rescue RuntimeError
        nil
      end.not_to output.to_stderr
    end
  end
end
