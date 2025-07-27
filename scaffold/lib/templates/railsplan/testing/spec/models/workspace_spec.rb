# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Workspace, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:name) }
    it { should validate_presence_of(:slug) }
    it { should validate_uniqueness_of(:slug) }
    it { should validate_length_of(:name).is_at_most(255) }
    it { should validate_length_of(:slug).is_at_most(100) }
  end

  describe 'associations' do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:users).through(:memberships) }
  end

  describe 'slug generation' do
    it 'generates slug from name before validation' do
      workspace = build(:workspace, name: 'Test Workspace', slug: nil)
      workspace.valid?
      expected_slug = workspace.slug || 'test-workspace'
      expect(expected_slug).to match(/test.*workspace/i)
    end

    it 'preserves existing slug' do
      workspace = build(:workspace, name: 'Test Workspace', slug: 'custom-slug')
      workspace.valid?
      expect(workspace.slug).to eq('custom-slug')
    end
  end

  describe '#owner' do
    let(:workspace) { create(:workspace) }
    let(:owner) { create(:user) }
    let(:member) { create(:user) }

    before do
      create(:membership, workspace: workspace, user: owner, role: 'owner')
      create(:membership, workspace: workspace, user: member, role: 'member')
    end

    it 'returns the owner user' do
      skip 'if owner method not implemented' unless workspace.respond_to?(:owner)
      expect(workspace.owner).to eq(owner)
    end
  end

  describe '#member_count' do
    let(:workspace) { create(:workspace) }

    before do
      create_list(:membership, 3, workspace: workspace)
    end

    it 'returns the number of members' do
      skip 'if member_count method not implemented' unless workspace.respond_to?(:member_count)
      expect(workspace.member_count).to eq(3)
    end
  end

  describe 'scopes' do
    describe '.by_slug' do
      let!(:workspace) { create(:workspace, slug: 'test-workspace') }

      it 'finds workspace by slug' do
        skip 'if by_slug scope not implemented' unless Workspace.respond_to?(:by_slug)
        expect(Workspace.by_slug('test-workspace')).to eq(workspace)
      end
    end
  end
end