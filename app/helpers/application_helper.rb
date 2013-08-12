module ApplicationHelper
  def time_tracker_for(user)
    TimeTracker.where(:user_id => user.id).first
  end

  def status_from_id(status_id)
    IssueStatus.where(:id => status_id).first
  end

  def statuses_list()
    IssueStatus.all
  end

  def to_status_options(statuses)
    options_from_collection_for_select(statuses, 'id', 'name')
  end

  def new_transition_from_options(transitions)
    statuses = []
    statuses_list().each { |status|
      statuses << status unless transitions.has_key?(status.id.to_s)
    }
    to_status_options(statuses)
  end

  def new_transition_to_options()
    to_status_options(statuses_list())
  end

  def global_allowed_to?(user, action)
    return false if user.nil?

    projects = Project.all
    projects.each { |p|
      if user.allowed_to?(action, p)
        return true
      end
    }

    false
  end
  
  def time_tracker_button_tag(user, options={})
    content_tag("span", time_tracker_link(user, options), :class => time_tracker_css(User.current()))
  end
  
  def time_tracker_link(user, options)
     time_tracker = time_tracker_for(user) 
     html = ""
     time_tracker_options = {:project_id => options[:project].id}
     time_tracker_options.merge!(:issue_id => options[:issue].id) unless options[:issue].nil?
     time_tracker_options.merge!(:next_issue_id => options[:next_issue].id) unless options[:next_issue].nil?
     time_tracker_options.merge!(:next_project_id => options[:next_project].id) unless options[:next_project].nil?
     
     
     if !time_tracker.nil?
       stop_label = '' 
       # A time tracker exists, display the stop action
       if !time_tracker.issue_id.nil?
         stop_label += ' #' + time_tracker.issue_id.to_s
       elsif !time_tracker.project_id.nil?
         stop_label += ' ' + Project.find(time_tracker.project_id).name unless Project.find(time_tracker.project_id).nil?
       else stop_label += ' ' + time_tracker.comments.to_s
       end 
       
       link_label = l(:stop_time_tracker).capitalize + stop_label
       url_options = { :controller => '/time_trackers', :action => 'stop', :time_tracker => time_tracker_options }
       link_class = 'icon icon-stop'
       link_id = 'time_tracker_stop'
     elsif !options[:project].nil? and user.allowed_to?(:use_time_tracker_plugin, nil, :global => true) and user.allowed_to?(:log_time, options[:project])
        # No time tracker is running, but the user has the rights to track time on this issue 
        # Display the start time tracker action
       if options[:issue].nil?
         link_label = l(:start_time_tracker).capitalize + ' ' +  options[:project].name
         link_id = "time_tracker_start_#{options[:project].identifier}"
       else
         link_label = l(:start_time_tracker).capitalize + ' #' +  options[:issue].id.to_s
         link_id = "time_tracker_start_issue_#{options[:issue].id}"
       end
       url_options = { :controller => '/time_trackers', :action => 'start', :time_tracker => time_tracker_options }
       link_class = 'icon icon-start' 
     end

     unless url_options.nil?
       html << link_to(link_label, url_for(url_options), { :class => link_class, :id => link_id})
       html << "<br>"     
       if options[:from_sidebar]
         html << javascript_tag do "$('##{link_id}').click(function (event) {
             time_tracker_action('#{url_for(url_options.merge(:format => :js))}');
             event.preventDefault(); // Prevent link from following its href
           });".html_safe
         end
       end
     end
       
     html.html_safe 
  end
  
  def time_tracker_css(object)
    "#{object.class.to_s.underscore}-#{object.id}-time_tracker"
  end

end
