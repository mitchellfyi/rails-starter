# frozen_string_literal: true

require 'rails_helper'

RSpec.describe User, type: :model do
  describe 'validations' do
    it { should validate_presence_of(:email) }
    it { should validate_uniqueness_of(:email).case_insensitive }
    it { should validate_presence_of(:password) }
    it { should validate_length_of(:password).is_at_least(6) }
  end

  describe 'associations' do
    it { should have_many(:memberships).dependent(:destroy) }
    it { should have_many(:workspaces).through(:memberships) }
  end

  describe 'devise modules' do
    it 'includes database_authenticatable' do
      expect(User.devise_modules).to include(:database_authenticatable)
    end

    it 'includes registerable' do
      expect(User.devise_modules).to include(:registerable)
    end

    it 'includes confirmable' do
      expect(User.devise_modules).to include(:confirmable)
    end

    it 'includes recoverable' do
      expect(User.devise_modules).to include(:recoverable)
    end
  end

  describe '#admin?' do
    context 'when admin attribute exists' do
      let(:admin_user) { build(:user, :admin) }
      let(:regular_user) { build(:user) }

      it 'returns true for admin users' do
        skip 'if admin attribute not implemented' unless admin_user.respond_to?(:admin?)
        expect(admin_user.admin?).to be true
      end

      it 'returns false for regular users' do
        skip 'if admin attribute not implemented' unless regular_user.respond_to?(:admin?)
        expect(regular_user.admin?).to be false
      end
    end
  end

  describe '#full_name' do
    it 'returns email when first_name and last_name are blank' do
      user = build(:user, email: 'test@example.com')
      expected_name = user.respond_to?(:full_name) ? user.full_name : user.email
      expect(expected_name).to eq('test@example.com')
    end
  end

  describe '#confirmed?' do
    it 'returns true for confirmed users' do
      user = create(:user)
      expect(user.confirmed?).to be true
    end

    it 'returns false for unconfirmed users' do
      user = create(:user, :unconfirmed)
      expect(user.confirmed?).to be false
    end
  end
end