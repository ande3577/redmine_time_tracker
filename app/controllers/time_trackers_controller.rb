class TimeTrackersController < ApplicationController
  unloadable

  menu_item :time_tracker_menu_tab_overview
  before_filter :js_auth, :authorize_global
  before_filter :get_issue, :only => [ :start, :stop ]
  before_filter :get_project, :only => [ :start, :stop ]
  before_filter :get_next_issue, :only => [:start, :stop]
  before_filter :get_next_project, :only => [:start, :stop]
  before_filter :get_comment, :only => [ :start, :stop ]

  helper :issues
  include IssuesHelper
  helper :time_trackers
  include TimeTrackersHelper  
  helper :timelog
  include TimelogHelper


  # we could start an empty timeTracker to track time without any association.
  # we also can give some more information, so the timeTracker could be automatically associated later.
  def start
    @time_tracker = get_current
    if @time_tracker.new_record?
      # parse comments for issue-id
      logger.debug "\n@comment = #{@comments}\n"
      if @issue.nil? && !@comments.nil? && @comments.strip.match(/\A#\d?\d*/)
        cut = @comments.strip.partition(/#\d?\d*/)
        @issue_id = cut[1].sub(/#/, "").to_i
        logger.debug "\n@issue_id = #{@issue_id}\n"
        unless help.issue_from_id(@issue_id).nil?
          @issue = Issue.where(:id => @issue_id).first
          @comments = cut[2].strip
        end
      end

      @time_tracker = TimeTracker.new(:issue_id => @issue_id, :project_id => @project_id, :comments => @comments)
      if @time_tracker.start
        apply_status_transition(@issue) unless Setting.plugin_redmine_time_tracker[:status_transitions] == nil
      else
        flash[:error] = l(:start_time_tracker_error)
      end
    else
      flash[:error] = l(:time_tracker_already_running_error)
    end
    respond_to do |format|
      format.html { redirect_to_referer_or {render :text => ('Time tracking started.'), :layout => true}}
      format.js { render :partial => "time_trackers/time_tracker_sidebar_control", :locals => { :project => @next_project, :issue => @next_issue } }
    end
  end

  def stop
    @time_tracker = get_current
    if @time_tracker.nil?
      flash[:error] = l(:no_time_tracker_running)
      redirect_to :back
    else
      unless params[:time_tracker].nil?
        @time_tracker.issue_id = @issue_id unless @issue_id.nil?
        @time_tracker.project_id =  @project_id unless @project_id.nil?
        @time_tracker.comments = @comments
      end
      @time_tracker.stop
      flash[:error] = l(:stop_time_tracker_error) unless @time_tracker.destroyed?
    end
	@time_tracker = get_current
    respond_to do |format|
      format.html { redirect_to_referer_or {render :text => ('Time tracking started.'), :layout => true}}
      format.js { render :partial => "time_trackers/time_tracker_sidebar_control", :locals => { :project => @next_project, :issue => @next_issue } }
    end
  end
  
  def cancel
    @time_tracker = get_current
    if @time_tracker.nil?
      flash[:error] = l(:no_time_tracker_running)
      redirect_to :back
    else
       @time_tracker.destroy
       if @time_tracker.destroyed?
         flash[:error] = l(:time_tracker_cancelled) 
       else
         flash[:error] = l(:stop_time_tracker_error)
       end
    end
    @time_tracker = get_current
    respond_to do |format|
      format.html { redirect_to_referer_or {render :text => ('Time tracking started.'), :layout => true}}
      format.js do
        render(:update) do |page|
          issue = Issue.where(:id => params[:time_tracker][:issue_id]).first
          if !issue.nil?
            c = time_tracker_css(User.current())
            page << %|$$(".#{c}").each(function(el){el.innerHTML="#{escape_javascript time_tracker_link(User.current, {:issue => issue, :project => project})}"});|
          end
        end
      end
    end

  end

  def delete
    time_tracker = TimeTracker.where(:id => params[:id]).first
    time_tracker = nil unless time_tracker.nil? || User.current.id == time_tracker.user_id || User.current.admin? # user could only delete his own entries, except he's admin
    if time_tracker.nil?
      flash[:error] = l(:time_tracker_delete_fail)
    else
      time_tracker.destroy
      flash[:notice] = l(:time_tracker_delete_success)
    end
    redirect_to_referer_or
  end

  def update
    @time_tracker = get_current
    @time_tracker.update_attributes!(params[:time_tracker])
    respond_to do |format|
      format.html { render :nothing => true }
      format.xml { render :xml => @time_tracker }
      format.json { render :json => @time_tracker }
    end
      # if something went wrong, return the original object
  rescue
    @time_tracker = get_current
    # todo figure out a way to show errors, even on ajax requests!
    flash[:error] = @time_tracker.errors.to_hash unless @time_tracker.errors.empty?
    respond_to do |format|
      format.html { render :nothing => true }
      format.xml { render :xml => @time_tracker }
      format.json { render :json => @time_tracker }
    end

  end

  def add_status_transition
    transitions = params[:transitions].nil? ? {} : params[:transitions]
    transitions[params[:from_id]] = params[:to_id]

    render :partial => 'status_transition_list', :locals => {:transitions => transitions}
  end

  def delete_status_transition
    transitions = params[:transitions].nil? ? {} : params[:transitions]
    transitions.delete(params[:from_id])

    render :partial => 'status_transition_list', :locals => {:transitions => transitions}
  end

  protected

  def get_current
    current = TimeTracker.where(:user_id => User.current.id).first
    current.nil? ? TimeTracker.new : current
  end

  def apply_status_transition(issue)
    unless issue == nil
      new_status_id = Setting.plugin_redmine_time_tracker[:status_transitions][issue.status_id.to_s]
      new_status = IssueStatus.where(:id => new_status_id).first
      if issue.new_statuses_allowed_to(User.current).include?(new_status)
        journal = issue.init_journal(User.current, notes = l(:time_tracker_label_transition_journal))
        issue.status_id = new_status_id
        issue.save
      end
    end
  end

  private

  # following method is necessary to got ajax requests logged_in
  def js_auth
    respond_to do |format|
      format.json { User.current = User.where(:id => session[:user_id]).first }
      format.any {}
    end
  end
  
  def get_issue
    begin
      @issue = Issue.where(:id => params[:issue_id]).first unless params[:issue_id].nil?
      @issue = Issue.where(:id => params[:time_tracker][:issue_id]).first if @issue.nil?
      @issue_id = @issue.id
    rescue
      @issue = nil
      @issue_id = nil
    end
  end
  
  def get_project
    begin
      @project = Project.where(:id => params[:project_id]).first unless params[:project_id].nil?
      @project = Project.where(:id => params[:time_tracker][:project_id]).first if @project.nil?
      @project_id = @project.id
    rescue
      @project = nil
      @project_id = nil
    end
  end
  
def get_next_issue
    begin
      @next_issue = Issue.where(:id => params[:next_issue_id]).first unless params[:next_issue_id].nil?
      @next_issue = Issue.where(:id => params[:time_tracker][:next_issue_id]).first if @next_issue.nil?
      @next_issue_id = @next_issue.id
    rescue
      @next_issue = nil
      @next_issue_id = nil
    end
  end
  
  def get_next_project
    begin
      @next_project = Project.where(:id => params[:next_project_id]).first unless params[:next_project_id].nil?
      @next_project = Project.where(:id => params[:time_tracker][:next_project_id]).first if @next_project.nil?
      @next_project_id = @next_project.id
    rescue
      @next_project = nil
      @next_project_id = nil
    end
  end
  
  def get_comment
    begin
      @comments = params[:comments]
      @comments = params[:time_tracker][:comments] if @comments.nil?
    rescue
      @comments = nil
    end
  end
end
