# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestFeatureItem, type: :model do
  let(:user) { create(:user) }
  
  describe 'validations' do
    it { should belong_to(:user) }
    it { should validate_presence_of(:name) }
    it { should validate_length_of(:name).is_at_least(2).is_at_most(100) }
    it { should validate_length_of(:description).is_at_most(500) }
  end

  describe 'scopes' do
    let!(:active_item) { create(:test_feature_item, user: user, active: true) }
    let!(:inactive_item) { create(:test_feature_item, user: user, active: false) }
    let!(:old_item) { create(:test_feature_item, user: user, created_at: 2.days.ago) }
    let!(:new_item) { create(:test_feature_item, user: user, created_at: 1.day.ago) }

    describe '.active' do
      it 'returns only active items' do
        expect(TestFeatureItem.active).to include(active_item)
        expect(TestFeatureItem.active).not_to include(inactive_item)
      end
    end

    describe '.recent' do
      it 'returns items ordered by creation date (newest first)' do
        recent_items = TestFeatureItem.recent
        expect(recent_items.first).to eq(new_item)
        expect(recent_items.second).to eq(old_item)
      end
    end
  end

  describe '#display_name' do
    let(:item) { build(:test_feature_item, user: user) }

    context 'when name is present' do
      it 'returns the name' do
        item.name = 'Test Item'
        expect(item.display_name).to eq('Test Item')
      end
    end

    context 'when name is blank' do
      it 'returns a default name' do
        item.name = ''
        expect(item.display_name).to eq('Untitled TestFeature')
      end
    end
  end

  describe '#to_s' do
    let(:item) { build(:test_feature_item, user: user, name: 'Test Item') }

    it 'returns the display name' do
      expect(item.to_s).to eq('Test Item')
    end
  end
end
