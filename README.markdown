# WARNING:

**This Plugin is in full development and therefore should NOT be considered stable or complete in any way. Do not expect any support until the anouncement of a stable release**

# Redmine Time Tracker plugin

Time tracker is a Redmine plugin to ease time tracking when working on an issue.
The plugin allows to start/stop a timer on a per user basis. The timer can be
started with or without any reference to a Redmine Issue.
If you track multiple timelogs without Issue references, you are able to reference
Issues later.

Later versions of the plugin will give you a better overview through statistics and add
the possabillity to generate invoices.
It will be individual adjustable for every user and seperate includable for any project.

Main features to track time referring to an issue should work allready.
The advanced features are going to be implemented soon.
My goal is to have a release with all main-features within the next two month
(that means till 08/2012)

The master branch supports redmine 2.3 only. Previous versions should use 2.2-branch.

![Overview](/img/TimeTracker-Overview.png "Overview")

![Issue](/img/TimeTracker-Issue.png "Issue Page")

## Features

* Per user time tracking
* Using known Redmine TimeEntries
* Overview of spent Time
* Track free time
* Book tracked time on tickets
* Detailed time tracking statistics for team management
* Status monitor, watch currently tracked time of team
* Detailed overview of spent time with filter options on (user, project, date)
* Invoice generation on project basis
* User specific settings (bookable hours per day, timetracking on/off)
* Project specific settings (timetracking on/off)
* Admin page (setup users bookable hours limit, add/remove timelogs)

## Getting the plugin

Most current version is available at: [GitHub](https://github.com/hicknhack-software/redmine_time_tracker).

## Install

1. Follow the Redmine plugin installation steps at http://www.redmine.org/wiki/redmine/Plugins Make sure the plugin is installed to `#{RAILS_ROOT}/plugins/redmine_time_tracker`
2. Setup the database using the migrations. `rake db:migrate_plugins RAILS_ENV=production`
3. Login to your Redmine install as an Administrator
4. Setup the "log time" permissions for your roles
5. Add "Time tracking" to the enabled modules for your project
6. The link to the plugin should appear in the Main menu bar (upper left corner)

## Usage

To be able to use a time tracker, a user must have the 'log time' permission.
Then, the time tracker menu will appear in the top left menu

To track time referring an issue, you can use the context menu (right click in the issues list) in
the issue list to start or stop the timer.

### Git

1. Open a shell to your Redmine's `#{RAILS_ROOT}/plugins/redmine_time_tracker` folder
2. Update your git copy with `git pull`
3. Update the database using the migrations. `rake db:migrate_plugins RAILS_ENV=production`
4. Restart your Redmine

