# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mcp::Registry do
  before { described_class.clear! }
  after { described_class.clear! }

  describe '.register' do
    let(:dummy_fetcher) { Class.new { def self.fetch(**params); { data: 'test' }; end } }

    it 'registers a fetcher under a key' do
      described_class.register(:test_fetcher, dummy_fetcher)
      expect(described_class.get(:test_fetcher)).to eq(dummy_fetcher)
    end

    it 'raises error if key is not a symbol' do
      expect {
        described_class.register('string_key', dummy_fetcher)
      }.to raise_error(ArgumentError, 'Key must be a symbol')
    end

    it 'raises error if fetcher does not respond to fetch' do
      invalid_fetcher = Class.new
      expect {
        described_class.register(:invalid, invalid_fetcher)
      }.to raise_error(ArgumentError, 'Fetcher must respond to :fetch')
    end
  end

  describe '.get' do
    let(:dummy_fetcher) { Class.new { def self.fetch(**params); { data: 'test' }; end } }

    it 'returns registered fetcher' do
      described_class.register(:test_fetcher, dummy_fetcher)
      expect(described_class.get(:test_fetcher)).to eq(dummy_fetcher)
    end

    it 'returns nil for unregistered key' do
      expect(described_class.get(:nonexistent)).to be_nil
    end
  end

  describe '.registered?' do
    let(:dummy_fetcher) { Class.new { def self.fetch(**params); { data: 'test' }; end } }

    it 'returns true for registered fetcher' do
      described_class.register(:test_fetcher, dummy_fetcher)
      expect(described_class.registered?(:test_fetcher)).to be true
    end

    it 'returns false for unregistered fetcher' do
      expect(described_class.registered?(:nonexistent)).to be false
    end
  end

  describe '.unregister' do
    let(:dummy_fetcher) { Class.new { def self.fetch(**params); { data: 'test' }; end } }

    it 'removes registered fetcher' do
      described_class.register(:test_fetcher, dummy_fetcher)
      result = described_class.unregister(:test_fetcher)
      
      expect(result).to eq(dummy_fetcher)
      expect(described_class.registered?(:test_fetcher)).to be false
    end

    it 'returns nil for unregistered key' do
      result = described_class.unregister(:nonexistent)
      expect(result).to be_nil
    end
  end

  describe '.keys' do
    let(:dummy_fetcher) { Class.new { def self.fetch(**params); { data: 'test' }; end } }

    it 'returns list of registered keys' do
      described_class.register(:fetcher_one, dummy_fetcher)
      described_class.register(:fetcher_two, dummy_fetcher)
      
      expect(described_class.keys).to contain_exactly(:fetcher_one, :fetcher_two)
    end

    it 'returns empty array when no fetchers registered' do
      expect(described_class.keys).to eq([])
    end
  end

  describe '.clear!' do
    let(:dummy_fetcher) { Class.new { def self.fetch(**params); { data: 'test' }; end } }

    it 'removes all registered fetchers' do
      described_class.register(:fetcher_one, dummy_fetcher)
      described_class.register(:fetcher_two, dummy_fetcher)
      
      described_class.clear!
      
      expect(described_class.keys).to be_empty
    end
  end
end