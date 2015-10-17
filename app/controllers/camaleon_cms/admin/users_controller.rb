=begin
  Camaleon CMS is a content management system
  Copyright (C) 2015 by Owen Peredo Diaz
  Email: owenperedo@gmail.com
  This program is free software: you can redistribute it and/or modify   it under the terms of the GNU Affero General Public License as  published by the Free Software Foundation, either version 3 of the  License, or (at your option) any later version.
  This program is distributed in the hope that it will be useful,  but WITHOUT ANY WARRANTY; without even the implied warranty of  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.
  See the  GNU Affero General Public License (GPLv3) for more details.
=end
class CamaleonCms::Admin::UsersController < CamaleonCms::AdminController
  before_action :validate_role, except: [:profile, :profile_edit]
  before_action :set_user, only: ['show', 'edit', 'update', 'destroy']

  def index
    @users = current_site.users.paginate(:page => params[:page], :per_page => current_site.admin_per_page)
  end

  def profile
    @user = params[:user_id].present? ? current_site.the_user(params[:user_id].to_i).object : current_user.object
    return edit
  end

  def profile_edit
    @user = current_user.object
    return edit
  end

  def show
    render 'profile'
  end

  def edit
    admin_breadcrumb_add("#{t('camaleon_cms.admin.button.edit')}")
    r = {user: @user, render: 'form' }
    hooks_run('user_edit', r)
    render r[:render]
  end

  def update
    if @user.update(params[:user])
      @user.set_meta_from_form(params[:meta]) if params[:meta].present?
      @user.set_field_values(params[:field_options])
      r = {user: @user, message: t('camaleon_cms.admin.users.message.updated'), params: params}; hooks_run('user_after_edited', r)
      flash[:notice] = r[:message]
      if current_user.id == @user.id
        redirect_to action: :profile_edit
      else
        redirect_to action: :index
      end
    else
      render 'form'
    end
  end

  # update som ajax requests from profile or user form
  def updated_ajax
    @user = current_site.users.find(params[:user_id])
    # update password
    if params[:password]
      if @user.authenticate(params[:password][:password_old])
        render inline: @user.update(params[:password]) ? "" : @user.errors.full_messages.join(', ')
      else
        render inline: t('camaleon_cms.admin.users.message.incorrect_old_password')
      end
    end
  end

  def new
    @user = current_site.users.new
    edit
  end

  def create
    user_data = params[:user]
    @user = current_site.users.new(user_data)
    if @user.save
      @user.set_meta_from_form(params[:meta]) if params[:meta].present?
      @user.set_field_values(params[:field_options])
      flash[:notice] = t('camaleon_cms.admin.users.message.created')
      redirect_to action: :index
    else
      render 'form'
    end
  end

  def destroy
    flash[:notice] = t('camaleon_cms.admin.users.message.deleted') if @user.destroy
    redirect_to action: :index
  end

  private

  def validate_role
    (params[:id].present? && current_user.id == params[:id]) || authorize!(:manager, :users)
  end

  def set_user
    begin
      @user = current_site.users.find(params[:id])
    rescue
      flash[:error] = t('camaleon_cms.admin.users.message.error')
      redirect_to admin_path
    end
  end
end
