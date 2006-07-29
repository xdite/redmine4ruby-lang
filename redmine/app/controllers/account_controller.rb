# redMine - project management software
# Copyright (C) 2006  Jean-Philippe Lang
#
# This program is free software; you can redistribute it and/or
# modify it under the terms of the GNU General Public License
# as published by the Free Software Foundation; either version 2
# of the License, or (at your option) any later version.
# 
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
# 
# You should have received a copy of the GNU General Public License
# along with this program; if not, write to the Free Software
# Foundation, Inc., 51 Franklin Street, Fifth Floor, Boston, MA  02110-1301, USA.

class AccountController < ApplicationController
  layout 'base'	
  helper :custom_fields
  include CustomFieldsHelper   
  
  # prevents login action to be filtered by check_if_login_required application scope filter
  skip_before_filter :check_if_login_required, :only => [:login, :lost_password, :register]
  before_filter :require_login, :except => [:show, :login, :lost_password, :register]

  # Show user's account
  def show
    @user = User.find(params[:id])
  end

  # Login request and validation
  def login
    if request.get?
      # Logout user
      self.logged_in_user = nil
    else
      # Authenticate user
      user = User.try_to_login(params[:login], params[:password])
      if user
        self.logged_in_user = user
        redirect_back_or_default :controller => 'account', :action => 'my_page'
      else
        flash[:notice] = l(:notice_account_invalid_creditentials)
      end
    end
  end

  # Log out current user and redirect to welcome page
  def logout
    self.logged_in_user = nil
    redirect_to :controller => ''
  end

  # Show logged in user's page
  def my_page
    @user = self.logged_in_user
    @reported_issues = Issue.find(:all, :conditions => ["author_id=?", @user.id], :limit => 10, :include => [ :status, :project, :tracker ], :order => 'issues.updated_on DESC')
    @assigned_issues = Issue.find(:all, :conditions => ["assigned_to_id=?", @user.id], :limit => 10, :include => [ :status, :project, :tracker ], :order => 'issues.updated_on DESC')
  end

  # Edit logged in user's account
  def my_account
    @user = self.logged_in_user
    if request.post? and @user.update_attributes(@params[:user])
      set_localization
      flash[:notice] = l(:notice_account_updated)
      self.logged_in_user.reload
    end
  end
	
  # Change logged in user's password
  def change_password
    @user = self.logged_in_user
    if @user.check_password?(@params[:password])
      @user.password, @user.password_confirmation = params[:new_password], params[:new_password_confirmation]
      flash[:notice] = l(:notice_account_password_updated) if @user.save
    else
      flash[:notice] = l(:notice_account_wrong_password)
    end
    render :action => 'my_account'
  end
  
  # Enable user to choose a new password
  def lost_password
    if params[:token]
      @token = Token.find_by_action_and_value("recovery", params[:token])
      redirect_to :controller => '' and return unless @token and !@token.expired?
      @user = @token.user
      if request.post?
        @user.password, @user.password_confirmation = params[:new_password], params[:new_password_confirmation]
        if @user.save
          @token.destroy
          flash[:notice] = l(:notice_account_password_updated)
          redirect_to :action => 'login'
          return
        end 
      end
      render :template => "account/password_recovery"
      return
    else
      if request.post?
        user = User.find_by_mail(params[:mail])      
        flash[:notice] = l(:notice_account_unknown_email) and return unless user
        token = Token.new(:user => user, :action => "recovery")
        if token.save
          Mailer.set_language_if_valid(Localization.lang)
          Mailer.deliver_lost_password(token)
          flash[:notice] = l(:notice_account_lost_email_sent)
          redirect_to :action => 'login'
          return
        end
      end
    end
  end
  
  # User self-registration
  def register
    redirect_to :controller => '' and return if $RDM_SELF_REGISTRATION == false
    if params[:token]
      token = Token.find_by_action_and_value("register", params[:token])
      redirect_to :controller => '' and return unless token and !token.expired?
      user = token.user
      redirect_to :controller => '' and return unless user.status == User::STATUS_REGISTERED
      user.status = User::STATUS_ACTIVE
      if user.save
        token.destroy
        flash[:notice] = l(:notice_account_activated)
        redirect_to :action => 'login'
        return
      end      
    else
      if request.get?
        @user = User.new(:language => $RDM_DEFAULT_LANG)
        @custom_values = UserCustomField.find(:all).collect { |x| CustomValue.new(:custom_field => x, :customized => @user) }
      else
        @user = User.new(params[:user])
        @user.admin = false
        @user.login = params[:user][:login]
        @user.status = User::STATUS_REGISTERED
        @user.password, @user.password_confirmation = params[:password], params[:password_confirmation]
        @custom_values = UserCustomField.find(:all).collect { |x| CustomValue.new(:custom_field => x, :customized => @user, :value => params["custom_fields"][x.id.to_s]) }
        @user.custom_values = @custom_values
        token = Token.new(:user => @user, :action => "register")
        if @user.save and token.save
          Mailer.set_language_if_valid(Localization.lang)
          Mailer.deliver_register(token)
          flash[:notice] = l(:notice_account_register_done)
          redirect_to :controller => ''
        end
      end
    end
  end
end