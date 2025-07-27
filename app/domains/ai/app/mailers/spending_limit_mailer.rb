# frozen_string_literal: true

class SpendingLimitMailer < ApplicationMailer
  default from: 'noreply@example.com'

  def limit_exceeded(email:, workspace:, limit_type:, limit_amount:, current_spend:)
    @workspace = workspace
    @limit_type = limit_type
    @limit_amount = limit_amount
    @current_spend = current_spend
    @percentage = (@current_spend / @limit_amount * 100).round(1)
    
    mail(
      to: email,
      subject: "AI Spending Limit Alert: #{@limit_type.humanize} limit exceeded for #{@workspace.name}"
    )
  end
end