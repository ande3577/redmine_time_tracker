class TimeBooking < ActiveRecord::Base
  unloadable

  attr_accessible :started_on, :stopped_at, :time_entry_id, :time_log_id, :virtual, :project, :project_id
  belongs_to :project
  belongs_to :time_log
  belongs_to :time_entry, :dependent => :delete
  has_one :virtual_comment, :dependent => :delete

  validates_presence_of :time_log_id
  validates :time_entry_id, :presence => true, :unless => Proc.new { |tb| tb.virtual }
  validates_associated :virtual_comment, :if => Proc.new { |tb| tb.virtual }

  # scope :last_two_weeks, where("started_on > ? ", (Time.now.localtime-2.weeks).beginning_of_day)

  def initialize(args = {}, options = {})
    ActiveRecord::Base.transaction do
      super(nil)
      self.save
      logger.debug "Time booking created with args: #{args}"
      # without issue_id, create an virtual booking!
      if args[:issue].nil?
        time_entry = create_time_entry({:user_id => args[:user_id], :comments => args[:comments], :started_on => args[:started_on].localtime, :activity_id => args[:activity_id], :hours => args[:hours], :project_id => args[:project_id]})
        super({:time_entry_id => time_entry.id, :time_log_id => args[:time_log_id], :started_on => args[:started_on], :stopped_at => args[:stopped_at], :project_id => args[:project_id]})
      else
        # create a normal booking
        # to enforce a user to "log time" the admin has to set the redmine permissions
        # current user could be the user himself or the admin. whoever it is, the peron needs the permission to do that
        # but in any way, the user_id which will be stored, is the user_id from the timeLog. this way the admin can book
        # times for any of his users..
          # TODO check for user-specific setup (limitations for bookable times etc)
        time_entry = create_time_entry({:issue => args[:issue], :user_id => args[:user_id], :comments => args[:comments], :started_on => args[:started_on].localtime, :activity_id => args[:activity_id], :hours => args[:hours]})
        super({:time_entry_id => time_entry.id, :time_log_id => args[:time_log_id], :started_on => args[:started_on], :stopped_at => args[:stopped_at], :project_id => args[:issue].project.id})
      end
    end
  end

  # returns the hours between two timestamps
  def hours_spent(time1 = started_on, time2 = stopped_at)
    ((time2.to_i - time1.to_i) / 3600.0).to_f
  end

  def get_formatted_time(time1 = started_on, time2 = stopped_at)
    help.time_dist2string(time2.to_i - time1.to_i)
  end

  def get_formatted_start_time
    self.started_on.to_time.localtime.strftime("%H:%M:%S") unless self.started_on.nil?
  end

  def get_formatted_stop_time
    self.stopped_at.to_time.localtime.strftime("%H:%M:%S") unless self.stopped_at.nil?
  end

  # we have to redefine some setters, to ensure a convenient way to update these attributes
  def update_issue_project(params = {})
    return unless self.user.id == User.current.id || User.current.admin? # users should only change their own entries or be admin
    
    user = self.user # use the user-info from the TimeLog, so the admin can change normal users entries too...
    comments = self.comments # store comments temporarily to swap them to the new place
    
    issue = params[:issue]
    project = params[:project]
    
    # if getting rid of both project and issue
    if project.nil? && issue.nil?
      self.time_entry.destroy unless self.time_entry.nil?
      write_attribute(:virtual, true)
      write_attribute(:comments, comments) # should create a virtual comment
    elsif !issue.nil?
      if issue.id != self.issue_id && user.allowed_to?(:log_time, issue.project)
        write_attribute(:issue_id, issue.id)
        write_attribute(:project_id, nil)
          
        if self.virtual? # self.virtual is true, than we've got a new issue due to the statement ahead. so we change from virtual to normal booking!
          self.virtual_comment.destroy
          write_attribute(:virtual, false)
        else # self not virtual? => we get a new issue, so we have to delete the old linkage
          self.time_entry.destroy
        end
        
        tea = TimeEntryActivity.where(:name => :time_tracker_activity).first
        time_entry = create_time_entry({:issue => issue, :user_id => user.id, :comments => comments, :started_on => self.started_on, :activity_id => tea.id, :hours => self.hours_spent})
  
        write_attribute(:time_entry_id, time_entry.id)
        write_attribute(:project_id, issue.project.id)
      end
    else
      if (!self.issue.nil? || project.id != self.project_id) && user.allowed_to?(:log_time, project)
        write_attribute(:issue_id, nil)
        write_attribute(:project_id, project.id)
        
        if self.virtual? # self.virtual is true, than we've got a new issue due to the statement ahead. so we change from virtual to normal booking!
          self.virtual_comment.destroy
          write_attribute(:virtual, false)
        else # self not virtual? => we get a new issue, so we have to delete the old linkage
          self.time_entry.destroy
        end
  
        tea = TimeEntryActivity.where(:name => :time_tracker_activity).first
        time_entry = create_time_entry({:project_id => project.id, :user_id => user, :comments => comments, :started_on => self.started_on, :activity_id => tea.id, :hours => self.hours_spent})
  
        write_attribute(:time_entry_id, time_entry.id)
      end
    end
  end

  # this method is necessary to change start and stop at the same time without leaving boundaries
  def update_time(start, stop)
    return if start == stop

    write_attribute(:started_on, start)
    write_attribute(:stopped_at, stop)
    self.time_entry.update_attributes(:spent_on => start, :hours => self.hours_spent) unless self.virtual? #also update TimeEntry
  end

  # following methods are necessary to use the query_patch, so we can use the powerful filter options of redmine
  # to show our booking lists => which will be the base for our invoices

  def comments
    if self.virtual
      self.virtual_comment.comments
    else
      self.time_entry.comments
    end
  end

  def comments=(comments)
    if self.virtual
      vcomment = VirtualComment.where(:time_booking_id => self.id).first_or_create
      vcomment.update_attributes :comments => comments
    else
      self.time_entry.update_attributes :comments => comments
    end
  end

  def issue
    if self.time_entry.nil?
      l(:time_tracker_label_none)
    else
      self.time_entry.issue
    end
  end

  def issue_id
    if self.time_entry.nil? || self.time_entry.issue.nil?
      l(:time_tracker_label_none)
    else
      self.time_entry.issue.id.to_s
    end
  end

  def tt_booking_date
    self.started_on.localtime.to_date.to_s(:db)
  end

  def user
    self.time_log.user
  end

  private
  
  def create_time_entry(args ={})
    # TODO check for user-specific setup (limitations for bookable times etc)
    # create a timeBooking to combine a timeLog-entry and a timeEntry
    if args[:issue].nil?
      time_entry = Project.find(args[:project_id]).time_entries.create({:comments => args[:comments], :spent_on => args[:started_on], :activity_id => args[:activity_id]})      
    else
      time_entry = args[:issue].time_entries.create({:comments => args[:comments], :spent_on => args[:started_on], :activity_id => args[:activity_id]})
    end
    time_entry.hours = args[:hours]
    # due to the mass-assignment security, we have to set the user_id extra
    time_entry.user_id = args[:user_id]
    time_entry.save
    time_entry
  end
end
