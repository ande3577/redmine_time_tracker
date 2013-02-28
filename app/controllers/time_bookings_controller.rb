class TimeBookingsController < ApplicationController
  unloadable

  before_filter :js_auth, :only => [:get_issue]
  before_filter :authorize_global

  helper :queries
  include QueriesHelper
  include TimeTrackersHelper

  def actions
    unless params[:time_booking_edit].nil?
      tb_e = params[:time_booking_edit]
      tb_e.keys.each do |tb_key|
        update tb_e[tb_key]
      end
    end

    redirect_to :back
  end

  def show_edit
    @time_bookings = TimeBooking.where(:id => params[:time_booking_ids]).all
    respond_to do |format|
      format.js
    end
  end
  
  def get_issue
    issue = Issue.where(:id => params[:id]).first
    respond_to do |format|
      format.json { render :json => issue }
    end
  end
    

  def update(tb)
    time_booking = TimeBooking.where(:id => tb[:id]).first
    tl = time_booking.time_log
    issue = Issue.where(:id => tb[:issue_id]).first
    issue.nil? ? project = Project.where(:id => tb[:project_id]).first : project = issue.project

    if time_booking.user.id == User.current.id || User.current.admin?
      start = Time.parse(tb[:tt_booking_date] + " " + tb[:start_time])
      hours = time_string2hour(tb[:spent_time])
      stop = start + hours.hours

      time_booking.update_time(start, stop)

      time_booking.update_issue_project(:issue => issue, :project => project)
      time_booking.comments = tb[:comments]

      time_booking.save!
      tl.check_bookable
    end
  end

  def delete
    time_bookings = TimeBooking.where(:id => params[:time_booking_ids]).all
    time_bookings.each do |item|
      #flash[:error] = l(:time_tracker_delete_booking_fail)
      tl = TimeLog.where(:id => item.time_log_id, :user_id => User.current.id).first
      item.destroy
      tl.destroy
      flash[:success] = l(:time_tracker_delete_booking_success)
    end
    redirect_to :back
  end

  def get_list_entry
    # prepare query for time_bookings
    time_bookings_query

    @entry = TimeBooking.where(:id => params[:time_booking_id]).first
    respond_to do |format|
      format.js
    end
  end
  
  # following method is necessary to got ajax requests logged_in
  def js_auth
    respond_to do |format|
      format.json { User.current = User.where(:id => session[:user_id]).first }
      format.any {}
    end
  end
end