class AddDefaultTtQuery < ActiveRecord::Migration
  def up
    IssueQuery.create :tt_query => true,
                 :visibility => IssueQuery::VISIBILITY_PUBLIC,
                 :name => I18n.t(:time_tracker_label_your_time_bookings),
                 :filters => {:tt_user => {:operator => "=", :values => ["me"]}},
                 :group_by => nil,
                 :column_names => [:project, :tt_booking_date, :get_formatted_start_time, :get_formatted_stop_time, :issue, :comments, :get_formatted_time]
  end

  def down
    query = IssueQuery.where(:tt_query => true,
                        :name => I18n.t(:time_tracker_label_your_time_bookings)).first # should be the first tt_query in the db..
    IssueQuery.destroy(query.id) unless query.nil?
  end
end