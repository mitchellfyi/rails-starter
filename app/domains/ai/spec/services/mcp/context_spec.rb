# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mcp::Context do
  let(:user) { double('User', id: 1, name: 'Test User') }
  let(:workspace) { double('Workspace', id: 1, name: 'Test Workspace') }
  let(:dummy_fetcher) { Class.new { def self.fetch(**params); { data: "fetched with #{params}" }; end } }
  let(:failing_fetcher) { Class.new { def self.fetch(**params); raise StandardError, 'Fetch failed'; end } }
  let(:fallback_fetcher) do
    Class.new do
      def self.fetch(**params)
        raise StandardError, 'Fetch failed'
      end
      
      def self.fallback_data(**params)
        { fallback: true, params: params }
      end
    end
  end

  before do
    Mcp::Registry.clear!
    Mcp::Registry.register(:test_fetcher, dummy_fetcher)
    Mcp::Registry.register(:failing_fetcher, failing_fetcher)
    Mcp::Registry.register(:fallback_fetcher, fallback_fetcher)
  end

  after { Mcp::Registry.clear! }

  describe '#initialize' do
    it 'stores base data' do
      context = described_class.new(user: user, workspace: workspace)
      expect(context.base_data).to eq(user: user, workspace: workspace)
    end

    it 'freezes base data to prevent modification' do
      context = described_class.new(user: user)
      expect(context.base_data).to be_frozen
    end

    it 'initializes empty fetched data and errors' do
      context = described_class.new(user: user)
      expect(context.fetched_data).to eq({})
      expect(context.errors).to eq({})
    end
  end

  describe '#fetch' do
    let(:context) { described_class.new(user: user, workspace: workspace) }

    it 'fetches data using registered fetcher' do
      result = context.fetch(:test_fetcher, limit: 10)
      
      expected_params = { user: user, workspace: workspace, limit: 10 }
      expect(result).to eq(data: "fetched with #{expected_params}")
      expect(context[:test_fetcher]).to eq(result)
    end

    it 'raises error for unregistered fetcher' do
      expect {
        context.fetch(:nonexistent_fetcher)
      }.to raise_error(ArgumentError, 'No fetcher registered for key: nonexistent_fetcher')
    end

    it 'handles fetcher errors and stores error message' do
      result = context.fetch(:failing_fetcher)
      
      expect(result).to eq({})
      expect(context.error?(:failing_fetcher)).to be true
      expect(context.error_message(:failing_fetcher)).to include('Failed to fetch data')
    end

    it 'uses fallback data when fetcher fails and fallback is available' do
      result = context.fetch(:fallback_fetcher, test: 'value')
      
      expected_params = { user: user, workspace: workspace, test: 'value' }
      expect(result).to eq(fallback: true, params: expected_params)
      expect(context[:fallback_fetcher]).to eq(result)
    end

    it 'merges base data with fetch parameters' do
      context.fetch(:test_fetcher, additional: 'param')
      
      expect(context[:test_fetcher]).to include(data: include('additional'))
      expect(context[:test_fetcher]).to include(data: include('user'))
    end
  end

  describe '#fetch_multiple' do
    let(:context) { described_class.new(user: user) }

    it 'fetches data for multiple keys' do
      context.fetch_multiple(:test_fetcher, [:test_fetcher, { limit: 5 }])
      
      expect(context.fetched_data.keys).to include(:test_fetcher)
      expect(context.fetched_data[:test_fetcher]).to be_present
    end

    it 'handles mixed key formats' do
      context.fetch_multiple(:test_fetcher, [:test_fetcher, { extra: 'param' }])
      
      expect(context.successful_keys).to include(:test_fetcher)
    end
  end

  describe '#to_h' do
    let(:context) { described_class.new(user: user, workspace: workspace) }

    it 'merges base data and fetched data' do
      context.fetch(:test_fetcher)
      result = context.to_h
      
      expect(result).to include(user: user, workspace: workspace)
      expect(result).to include(:test_fetcher)
    end
  end

  describe '#success?' do
    let(:context) { described_class.new(user: user) }

    it 'returns true for successful fetch' do
      context.fetch(:test_fetcher)
      expect(context.success?(:test_fetcher)).to be true
    end

    it 'returns false for failed fetch' do
      context.fetch(:failing_fetcher)
      expect(context.success?(:failing_fetcher)).to be false
    end

    it 'returns false for unfetched key' do
      expect(context.success?(:unfetched)).to be false
    end
  end

  describe '#error?' do
    let(:context) { described_class.new(user: user) }

    it 'returns true for failed fetch' do
      context.fetch(:failing_fetcher)
      expect(context.error?(:failing_fetcher)).to be true
    end

    it 'returns false for successful fetch' do
      context.fetch(:test_fetcher)
      expect(context.error?(:test_fetcher)).to be false
    end
  end

  describe '#has_errors?' do
    let(:context) { described_class.new(user: user) }

    it 'returns true when any errors occurred' do
      context.fetch(:failing_fetcher)
      expect(context.has_errors?).to be true
    end

    it 'returns false when no errors occurred' do
      context.fetch(:test_fetcher)
      expect(context.has_errors?).to be false
    end
  end

  describe '#successful_keys and #error_keys' do
    let(:context) { described_class.new(user: user) }

    it 'correctly categorizes successful and error keys' do
      context.fetch(:test_fetcher)
      context.fetch(:failing_fetcher)
      
      expect(context.successful_keys).to eq([:test_fetcher])
      expect(context.error_keys).to eq([:failing_fetcher])
    end
  end

  describe '#reset!' do
    let(:context) { described_class.new(user: user) }

    it 'clears fetched data and errors' do
      context.fetch(:test_fetcher)
      context.fetch(:failing_fetcher)
      
      context.reset!
      
      expect(context.fetched_data).to be_empty
      expect(context.errors).to be_empty
    end

    it 'preserves base data' do
      context.fetch(:test_fetcher)
      context.reset!
      
      expect(context.base_data).to eq(user: user)
    end
  end
end