# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Mcp::Fetcher::Database do
  let(:user) { double('User', id: 1) }
  let(:workspace) { double('Workspace', id: 1) }
  
  # Mock ActiveRecord model
  let(:mock_model) do
    Class.new do
      def self.name
        'MockModel'
      end
      
      def self.all
        MockRelation.new
      end
      
      def self.column_names
        %w[id name user_id workspace_id created_at]
      end
      
      def self.respond_to?(method_name)
        [:recent, :active].include?(method_name) || super
      end
      
      def self.recent(date = 1.week.ago)
        MockRelation.new.where(created_at: date..)
      end
      
      def as_json
        { id: 1, name: 'Test Record' }
      end
      
      def attributes
        { 'id' => 1, 'name' => 'Test Record' }
      end
    end
  end

  # Mock ActiveRecord relation
  let(:mock_relation) do
    Class.new do
      def initialize(records = [])
        @records = records
      end
      
      def klass
        MockModel
      end
      
      def where(conditions)
        self.class.new(@records)
      end
      
      def limit(count)
        self.class.new(@records.first(count))
      end
      
      def offset(count)
        self.class.new(@records.drop(count))
      end
      
      def order(ordering)
        self.class.new(@records)
      end
      
      def except(*methods)
        self.class.new(@records)
      end
      
      def count
        @records.size
      end
      
      def to_a
        @records.map { MockModel.new }
      end
      
      def method_missing(method_name, *args)
        if MockModel.respond_to?(method_name)
          MockModel.public_send(method_name, *args)
        else
          super
        end
      end
      
      def respond_to_missing?(method_name, include_private = false)
        MockModel.respond_to?(method_name) || super
      end
      
      private
      
      class MockModel
        def self.new
          model = Object.new
          model.define_singleton_method(:as_json) { { id: 1, name: 'Test Record' } }
          model.define_singleton_method(:attributes) { { 'id' => 1, 'name' => 'Test Record' } }
          model
        end
      end
    end
  end

  before do
    # Mock the constantize method
    allow(String).to receive(:constantize) do |str|
      case str
      when 'MockModel', 'mock_model'
        mock_model
      else
        raise NameError, "uninitialized constant #{str}"
      end
    end
    
    # Mock Rails.logger
    unless defined?(Rails)
      rails_double = double('Rails')
      logger_double = double('Logger')
      allow(logger_double).to receive(:warn)
      allow(rails_double).to receive(:logger).and_return(logger_double)
      stub_const('Rails', rails_double)
    end
  end

  describe '.fetch' do
    it 'fetches records using model name' do
      allow(mock_model).to receive(:all).and_return(mock_relation.new([1, 2, 3]))
      
      result = described_class.fetch(model: 'MockModel', limit: 10)
      
      expect(result[:model]).to eq('MockModel')
      expect(result[:count]).to eq(3)
      expect(result[:records]).to be_an(Array)
    end

    it 'applies user scoping when model has user_id column' do
      relation = mock_relation.new([1, 2, 3])
      allow(mock_model).to receive(:all).and_return(relation)
      expect(relation).to receive(:where).with(user: user).and_return(relation)
      
      described_class.fetch(model: mock_model, user: user)
    end

    it 'applies workspace scoping when model has workspace_id column' do
      relation = mock_relation.new([1, 2, 3])
      allow(mock_model).to receive(:all).and_return(relation)
      expect(relation).to receive(:where).with(workspace: workspace).and_return(relation)
      
      described_class.fetch(model: mock_model, workspace: workspace)
    end

    it 'applies custom scope with arguments' do
      relation = mock_relation.new([1, 2, 3])
      allow(mock_model).to receive(:all).and_return(relation)
      
      result = described_class.fetch(
        model: mock_model, 
        scope: :recent, 
        scope_args: [2.weeks.ago]
      )
      
      expect(result[:query_info][:scope]).to eq(:recent)
    end

    it 'applies conditions' do
      relation = mock_relation.new([1, 2, 3])
      allow(mock_model).to receive(:all).and_return(relation)
      expect(relation).to receive(:where).with(name: 'test').and_return(relation)
      
      described_class.fetch(model: mock_model, conditions: { name: 'test' })
    end

    it 'applies limit and offset' do
      relation = mock_relation.new([1, 2, 3])
      allow(mock_model).to receive(:all).and_return(relation)
      expect(relation).to receive(:limit).with(5).and_return(relation)
      expect(relation).to receive(:offset).with(10).and_return(relation)
      
      described_class.fetch(model: mock_model, limit: 5, offset: 10)
    end

    it 'applies ordering' do
      relation = mock_relation.new([1, 2, 3])
      allow(mock_model).to receive(:all).and_return(relation)
      expect(relation).to receive(:order).with('created_at DESC').and_return(relation)
      
      described_class.fetch(model: mock_model, order: 'created_at DESC')
    end

    it 'raises error for invalid model' do
      expect {
        described_class.fetch(model: 'NonexistentModel')
      }.to raise_error(ArgumentError, /Invalid model/)
    end

    it 'raises error when model parameter is missing' do
      expect {
        described_class.fetch({})
      }.to raise_error(ArgumentError, /Missing required parameters: model/)
    end
  end

  describe '.fallback_data' do
    it 'returns fallback structure' do
      result = described_class.fallback_data(model: 'TestModel')
      
      expect(result).to include(
        model: 'TestModel',
        count: 0,
        total_count: 0,
        records: [],
        error: 'Failed to fetch data from database'
      )
    end
  end

  describe '.allowed_params' do
    it 'includes expected parameters' do
      params = described_class.allowed_params
      
      expect(params).to include(:model, :scope, :conditions, :limit, :user, :workspace)
    end
  end

  describe '.required_params' do
    it 'requires model parameter' do
      expect(described_class.required_params).to eq([:model])
    end
  end

  describe '.description' do
    it 'returns descriptive text' do
      expect(described_class.description).to include('ActiveRecord')
    end
  end
end