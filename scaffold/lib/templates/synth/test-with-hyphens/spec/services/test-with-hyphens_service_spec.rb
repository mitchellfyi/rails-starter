# frozen_string_literal: true

require 'rails_helper'

RSpec.describe TestWithHyphensService do
  let(:user) { create(:user) }
  let(:service) { described_class.new(user) }

  describe '#initialize' do
    it 'sets the user' do
      expect(service.user).to eq(user)
    end

    it 'initializes empty errors' do
      expect(service.errors).to be_empty
    end
  end

  describe '#create_item' do
    let(:attributes) { { name: 'Test Item', description: 'Test Description' } }

    context 'with valid attributes' do
      it 'creates a new item' do
        expect {
          service.create_item(attributes)
        }.to change(TestWithHyphensItem, :count).by(1)
      end

      it 'returns the created item' do
        item = service.create_item(attributes)
        expect(item).to be_a(TestWithHyphensItem)
        expect(item.name).to eq('Test Item')
        expect(item.user).to eq(user)
      end

      it 'has no errors' do
        service.create_item(attributes)
        expect(service).to be_valid
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { name: '' } }

      it 'does not create an item' do
        expect {
          service.create_item(invalid_attributes)
        }.not_to change(TestWithHyphensItem, :count)
      end

      it 'returns nil' do
        item = service.create_item(invalid_attributes)
        expect(item).to be_nil
      end

      it 'has errors' do
        service.create_item(invalid_attributes)
        expect(service).not_to be_valid
        expect(service.errors).not_to be_empty
      end
    end
  end

  describe '#update_item' do
    let(:item) { create(:test-with-hyphens_item, user: user, name: 'Original Name') }
    let(:attributes) { { name: 'Updated Name' } }

    context 'with valid attributes' do
      it 'updates the item' do
        updated_item = service.update_item(item, attributes)
        expect(updated_item.name).to eq('Updated Name')
      end

      it 'returns the updated item' do
        updated_item = service.update_item(item, attributes)
        expect(updated_item).to eq(item)
      end

      it 'has no errors' do
        service.update_item(item, attributes)
        expect(service).to be_valid
      end
    end

    context 'with invalid attributes' do
      let(:invalid_attributes) { { name: '' } }

      it 'does not update the item' do
        service.update_item(item, invalid_attributes)
        item.reload
        expect(item.name).to eq('Original Name')
      end

      it 'returns nil' do
        result = service.update_item(item, invalid_attributes)
        expect(result).to be_nil
      end

      it 'has errors' do
        service.update_item(item, invalid_attributes)
        expect(service).not_to be_valid
        expect(service.errors).not_to be_empty
      end
    end
  end

  describe '#delete_item' do
    let(:item) { create(:test-with-hyphens_item, user: user) }

    it 'destroys the item' do
      expect {
        service.delete_item(item)
      }.to change(TestWithHyphensItem, :count).by(-1)
    end

    it 'returns true on success' do
      result = service.delete_item(item)
      expect(result).to be true
    end

    it 'has no errors' do
      service.delete_item(item)
      expect(service).to be_valid
    end
  end

  describe '#valid?' do
    it 'returns true when no errors' do
      expect(service).to be_valid
    end

    it 'returns false when there are errors' do
      service.create_item({ name: '' })
      expect(service).not_to be_valid
    end
  end
end
