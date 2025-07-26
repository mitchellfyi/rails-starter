# frozen_string_literal: true

require 'rails_helper'

RSpec.describe 'Billing Management', type: :system do
  let(:user) { create(:user) }
  let(:workspace) { create(:workspace) }
  let!(:membership) { create(:membership, user: user, workspace: workspace, role: 'owner') }

  before do
    sign_in user
    driven_by(:rack_test)
  end

  describe 'subscription management' do
    scenario 'owner views subscription details' do
      subscription = create(:subscription, workspace: workspace, status: 'active')
      
      visit workspace_billing_path(workspace)
      
      expect(page).to have_content('Pro Plan')
      expect(page).to have_content('$29.99')
      expect(page).to have_content('Active')
    end

    scenario 'owner upgrades subscription plan' do
      subscription = create(:subscription, workspace: workspace, status: 'active')
      
      visit workspace_billing_path(workspace)
      click_link 'Change Plan'
      
      choose 'Enterprise Plan'
      click_button 'Upgrade Plan'
      
      expect(page).to have_content('Plan updated successfully')
        .or(have_content('Upgrade confirmed'))
    end

    scenario 'owner cancels subscription' do
      subscription = create(:subscription, workspace: workspace, status: 'active')
      
      visit workspace_billing_path(workspace)
      click_link 'Cancel Subscription'
      
      fill_in 'Cancellation reason', with: 'No longer needed'
      click_button 'Confirm Cancellation'
      
      expect(page).to have_content('Subscription canceled')
        .or(have_content('Your subscription has been canceled'))
    end

    scenario 'trial subscription shows trial information' do
      subscription = create(:subscription, :trialing, workspace: workspace)
      
      visit workspace_billing_path(workspace)
      
      expect(page).to have_content('Trial')
      expect(page).to have_content('days remaining')
      expect(page).to have_content('Add Payment Method')
    end
  end

  describe 'payment method management' do
    let!(:subscription) { create(:subscription, workspace: workspace) }

    scenario 'owner adds payment method' do
      visit workspace_billing_path(workspace)
      click_link 'Add Payment Method'
      
      # Mock Stripe Elements interaction
      fill_in 'cardholder_name', with: 'John Doe'
      click_button 'Add Payment Method'
      
      expect(page).to have_content('Payment method added')
        .or(have_content('Card saved successfully'))
    end

    scenario 'owner views payment methods' do
      payment_method = create(:payment_method, workspace: workspace)
      
      visit workspace_billing_path(workspace)
      click_link 'Payment Methods'
      
      expect(page).to have_content('Visa')
      expect(page).to have_content('•••• 4242')
      expect(page).to have_content('Default')
    end

    scenario 'owner removes payment method' do
      payment_method1 = create(:payment_method, workspace: workspace, is_default: true)
      payment_method2 = create(:payment_method, workspace: workspace, is_default: false)
      
      visit workspace_payment_methods_path(workspace)
      
      within("[data-payment-method-id='#{payment_method2.id}']") do
        click_button 'Remove'
      end
      
      expect(page).not_to have_content(payment_method2.card_last4)
    end
  end

  describe 'invoice management' do
    let!(:subscription) { create(:subscription, workspace: workspace) }

    scenario 'owner views invoice history' do
      invoice1 = create(:invoice, workspace: workspace, status: 'paid')
      invoice2 = create(:invoice, workspace: workspace, :unpaid)
      
      visit workspace_billing_path(workspace)
      click_link 'Invoice History'
      
      expect(page).to have_content('$29.99')
      expect(page).to have_content('Paid')
      expect(page).to have_content('Open')
    end

    scenario 'owner downloads invoice PDF' do
      invoice = create(:invoice, workspace: workspace, status: 'paid')
      
      visit workspace_invoices_path(workspace)
      
      within("[data-invoice-id='#{invoice.id}']") do
        click_link 'Download PDF'
      end
      
      # Check that PDF download is initiated
      expect(page.response_headers['Content-Type']).to include('application/pdf')
    end

    scenario 'owner pays overdue invoice' do
      invoice = create(:invoice, workspace: workspace, :overdue)
      
      visit workspace_invoices_path(workspace)
      
      within("[data-invoice-id='#{invoice.id}']") do
        click_button 'Pay Now'
      end
      
      expect(page).to have_content('Payment processed')
        .or(have_content('Invoice paid successfully'))
    end
  end

  describe 'billing permissions' do
    scenario 'non-owner cannot access billing settings' do
      member_user = create(:user)
      create(:membership, user: member_user, workspace: workspace, role: 'member')
      
      sign_out user
      sign_in member_user
      
      visit workspace_billing_path(workspace)
      
      expect(page).to have_content('Access denied')
        .or(have_content('Not authorized'))
        .or(have_current_path(workspace_path(workspace)))
    end

    scenario 'admin can view but not modify billing' do
      admin_user = create(:user)
      create(:membership, user: admin_user, workspace: workspace, role: 'admin')
      
      sign_out user
      sign_in admin_user
      
      visit workspace_billing_path(workspace)
      
      expect(page).to have_content('Subscription')
      expect(page).not_to have_link('Cancel Subscription')
      expect(page).not_to have_link('Change Plan')
    end
  end

  describe 'subscription limits' do
    scenario 'free plan shows upgrade prompts' do
      # No subscription = free plan
      visit workspace_path(workspace)
      
      expect(page).to have_content('Upgrade to unlock')
        .or(have_content('Upgrade your plan'))
    end

    scenario 'pro plan shows usage information' do
      subscription = create(:subscription, workspace: workspace, plan_name: 'Pro Plan')
      
      visit workspace_path(workspace)
      
      expect(page).to have_content('Pro Plan')
      expect(page).to have_content('usage')
        .or(have_content('limits'))
    end
  end
end