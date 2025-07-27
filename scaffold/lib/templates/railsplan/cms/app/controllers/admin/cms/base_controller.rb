# frozen_string_literal: true

class Admin::Cms::BaseController < ApplicationController
  before_action :authenticate_user!
  before_action :ensure_admin!
  layout 'admin'

  private

  def ensure_admin!
    redirect_to root_path unless current_user&.admin?
  end

  def set_breadcrumbs(*crumbs)
    @breadcrumbs = [
      { name: 'Dashboard', path: admin_root_path },
      { name: 'CMS', path: admin_cms_root_path }
    ] + crumbs.map { |crumb| crumb.is_a?(Hash) ? crumb : { name: crumb, path: nil } }
  end
end