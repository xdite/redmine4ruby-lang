# Customized version of redMine the prject management system.
# Copyright (C) 2008 Yuki Sonoda (Yugui)
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


class MailingListsController < ApplicationController
  layout 'base'
  before_filter :require_admin

  helper :sort
  include SortHelper

  def index
    list
  end

  def list
    sort_init 'name', 'asc'
    sort_update

    @mailing_lists = MailingList.find(:all)
    @mailing_list_count = MailingList.count
    @mailing_list_pages = Paginator.new self, @mailing_list_count, per_page_option, params['page']

    respond_to do |format|
      format.html { 
        if request.xhr?
          render :layout => false, :action => 'list'
        else
          render :action => 'list' 
        end
      }
      format.xml  { render :xml => @mailing_lists }
    end
  end

  def add
    @mailing_list = MailingList.new(params[:mailing_list])
    if request.get?
      respond_to do |format|
        format.html # add.html.erb
        format.xml  { render :xml => @mailing_list }
      end
    else
      respond_to do |format|
        if @mailing_list.save
          flash[:notice] = l(:notice_successful_create)
          format.html { redirect_to(:action => 'index') }
          format.xml  { render :xml => @mailing_list, :status => :created, :location => @mailing_list }
        else
          format.html # add.html.erb
          format.xml  { render :xml => @mailing_list.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  def edit
    @mailing_list = MailingList.find(params[:id])
    @projects = Project.find(:all, :order => 'name', :conditions => "status=#{Project::STATUS_ACTIVE}") - @mailing_list.projects
    @tracking = MailingListTracking.new
    unless request.get?
      respond_to do |format|
        if @mailing_list.update_attributes(params[:mailing_list])
          flash[:notice] = l(:notice_successful_update)
          format.html { redirect_to(:action => 'edit', :id => @mailing_list) }
          format.xml  { head :ok }
        else
          format.html { render :action => "edit" }
          format.xml  { render :xml => @mailing_list.errors, :status => :unprocessable_entity }
        end
      end
    end
  end

  def destroy
    @mailing_list = MailingList.find(params[:id])
    @mailing_list.destroy

    respond_to do |format|
      format.html { redirect_to(:action => 'index') }
      format.xml  { head :ok }
    end
  end

  def edit_tracking
    @mailing_list = MailingList.find(params[:id])
    @tracking = params[:tracking_id] ? MailingListTracking.find(params[:tracking_id]) : MailingListTracking.new(:mailing_list => @mailing_list)
    @tracking.attributes = params[:tracking]
    if request.post? and @tracking.save
      flash[:notice] = l(:notice_successful_update)
    end
    redirect_to :action => 'edit', :id => @mailing_list and return
  end

  def destroy_tracking
    @mailing_list = MailingList.find(params[:id])
    if request.post? and @mailing_list.mailing_list_trackings.destroy(params[:tracking_id])
      flash[:notice] = l(:notice_successful_update)
    end
    redirect_to :action => 'edit', :id => @mailing_list and return
  end

end
