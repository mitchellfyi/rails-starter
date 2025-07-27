# frozen_string_literal: true

class User < ApplicationRecord
  validates :email, presence: true, uniqueness: true
  validates :email, format: { with: URI::MailTo::EMAIL_REGEXP }
  
  def admin?
    admin == true
  end
  
  def full_name
    [first_name, last_name].compact.join(' ').presence || email
  end
end