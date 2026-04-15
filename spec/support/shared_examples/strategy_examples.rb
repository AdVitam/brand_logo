# frozen_string_literal: true

RSpec.shared_examples 'a favicon strategy' do
  it { is_expected.to respond_to(:fetch).with(1).argument }
  it { is_expected.to respond_to(:fetch_all).with(1).argument }

  describe '#fetch' do
    context 'when no icon is found' do
      it 'returns nil' do
        expect(subject.fetch('notfound.example.com')).to be_nil
      end
    end
  end

  describe '#fetch_all' do
    context 'when no icon is found' do
      it 'returns an empty array' do
        expect(subject.fetch_all('notfound.example.com')).to eq([])
      end
    end

    it 'returns an array of Icon objects' do
      result = subject.fetch_all('notfound.example.com')
      expect(result).to be_an(Array)
      expect(result).to all(be_a(BrandLogo::Icon))
    end
  end
end
