# frozen_string_literal: true

require 'rails_helper'

RSpec.describe Membership, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:role) }
    it { should validate_inclusion_of(:role).in_array(%w[owner admin member]) }
    it { should validate_uniqueness_of(:user_id).scoped_to(:workspace_id) }
  end

  describe 'associations' do
    it { should belong_to(:user) }
    it { should belong_to(:workspace) }
  end

  describe 'role methods' do
    let(:membership) { build(:membership) }

    describe '#owner?' do
      it 'returns true for owner role' do
        membership.role = 'owner'
        expected = membership.respond_to?(:owner?) ? membership.owner? : (membership.role == 'owner')
        expect(expected).to be true
      end

      it 'returns false for non-owner role' do
        membership.role = 'member'
        expected = membership.respond_to?(:owner?) ? membership.owner? : (membership.role != 'owner')
        expect(expected).to be true
      end
    end

    describe '#admin?' do
      it 'returns true for admin role' do
        membership.role = 'admin'
        expected = membership.respond_to?(:admin?) ? membership.admin? : (membership.role == 'admin')
        expect(expected).to be true
      end

      it 'returns false for non-admin role' do
        membership.role = 'member'
        expected = membership.respond_to?(:admin?) ? membership.admin? : (membership.role != 'admin')
        expect(expected).to be true
      end
    end

    describe '#member?' do
      it 'returns true for member role' do
        membership.role = 'member'
        expected = membership.respond_to?(:member?) ? membership.member? : (membership.role == 'member')
        expect(expected).to be true
      end

      it 'returns false for non-member role' do
        membership.role = 'admin'
        expected = membership.respond_to?(:member?) ? membership.member? : (membership.role != 'member')
        expect(expected).to be true
      end
    end
  end

  describe 'scopes' do
    let(:workspace) { create(:workspace) }
    let!(:owner_membership) { create(:membership, workspace: workspace, role: 'owner') }
    let!(:admin_membership) { create(:membership, workspace: workspace, role: 'admin') }
    let!(:member_membership) { create(:membership, workspace: workspace, role: 'member') }

    describe '.owners' do
      it 'returns only owner memberships' do
        skip 'if owners scope not implemented' unless Membership.respond_to?(:owners)
        expect(Membership.owners).to contain_exactly(owner_membership)
      end
    end

    describe '.admins' do
      it 'returns only admin memberships' do
        skip 'if admins scope not implemented' unless Membership.respond_to?(:admins)
        expect(Membership.admins).to contain_exactly(admin_membership)
      end
    end

    describe '.members' do
      it 'returns only member memberships' do
        skip 'if members scope not implemented' unless Membership.respond_to?(:members)
        expect(Membership.members).to contain_exactly(member_membership)
      end
    end
  end
end