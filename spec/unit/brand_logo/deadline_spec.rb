# frozen_string_literal: true

RSpec.describe BrandLogo::Deadline do
  it 'has remaining time within the budget' do
    deadline = described_class.new(10)

    expect(deadline.remaining).to be_between(9.0, 10.0)
    expect(deadline).not_to be_expired
  end

  it 'counts down with the monotonic clock' do
    deadline = described_class.new(10)
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    allow(Process).to receive(:clock_gettime).and_call_original
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(now + 4)

    expect(deadline.remaining).to be_within(0.1).of(6.0)
  end

  it 'expires and never goes negative' do
    deadline = described_class.new(0.01)
    now = Process.clock_gettime(Process::CLOCK_MONOTONIC)
    allow(Process).to receive(:clock_gettime).and_call_original
    allow(Process).to receive(:clock_gettime).with(Process::CLOCK_MONOTONIC).and_return(now + 100)

    expect(deadline.remaining).to eq(0.0)
    expect(deadline).to be_expired
  end
end
