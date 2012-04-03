module Trackmine

  class << self
    attr_writer :error_notification

    # Gets data from config/trackmine.yml
    def get_credentials
      trackmine_path = File.join(Rails.root, 'config', 'trackmine.yml')
      raise MissingTrackmineConfig.new("Missing trackmine.yml configuration file in /config") unless File.exist?(trackmine_path)
      YAML.load_file(trackmine_path)
    end

    # Sets email for error notification
    def set_error_notification
      @error_notification = get_credentials['error_notification']
    end

    # Gets email for error notification
    def error_notification
      @error_notification
    end

    # Returns all projects for the current user
    def projects
      PivotalTracker::Project.all
    end

    # Sets PivotalTracker token using user credentials from config/trackmine.yml
    def set_token(email)
      pivotal_token = get_credentials[email] || get_credentials['default_pivotal_token']

      raise MissingCredentials.new("Missing credentials for trackmine.yml") if pivotal_token.nil?
      begin
        PivotalTracker::Client.token = pivotal_token
        PivotalTracker::Client.use_ssl = true # to access pivotal projects which use https
      rescue => e
        raise WrongCredentials.new("Wrong Pivotal Tracker credentials in trackmine.yml. #{e}")
      end
    end

    # Returns all labels from specified Pivotal Tracker project
    def project_labels(tracker_project_id)
      tracker_project = PivotalTracker::Project.find tracker_project_id
      tracker_project.stories.all.select{|s| !s.labels.nil?}.collect{|s| Unicode.downcase(s.labels) }.join(',').split(',').uniq # ugly code but works fine
    end

    # Main method parsing PivotalTracker activity
    def read_activity(activity)
      story = activity['stories'][0] # PT API has changed! activity['stories']['story'] doesn't work any more
      issues = Issue.find_by_story_id story['id'].to_s
      unless issues.empty?
        if story['current_state'] == "started"
          story_restart(issues, activity)
        else
          issues.each {|issue| update_state(issue,story) }
        end
        story_url = get_story(activity).url
        update_issues(issues, activity['project_id'], {:description => story_url +"\r\n"+ story['description']}) if story['description']
        update_issues(issues, activity['project_id'], {:subject => story['name']}) if story['name']
      end
    end

    # Finds author of the tracker activity and returns its email
    def get_user_email(project_id, name)
      begin
        set_super_token
        project = PivotalTracker::Project.find project_id.to_i
         project.memberships.all.select{|m| m.name == name }[0].email
      rescue => e
        raise WrongActivityData.new("Can't get email of the Tracker user: #{name} in project id: #{project_id}. " + e)
      end
    end

    def update_state(issue, story)
      case story['current_state']
      when 'accepted'
        finished_issue_state = IssueStatus.find_by_name "Closed"
        issue.update_attributes(:status_id => finished_issue_state.id)
      when 'delivered'
        finished_issue_state = IssueStatus.find_by_name "Review"
        issue.update_attributes(:status_id => finished_issue_state.id)
      end
    end

    # Return PivotalTracker story for given activity
    def get_story(activity)
      begin
        set_super_token
        project_id = activity['project_id']
        story_id = activity['stories'][0]['id']
        story = PivotalTracker::Project.find(project_id).stories.find(story_id)
        raise 'Got empty story' if story.nil?
      rescue => e
        raise WrongActivityData.new("Can't get story: #{story_id} from Pivotal Tracker project: #{project_id}. " + e)
      end
      return story
    end


    # Updates Redmine issues
    def update_issues( issues, tracker_project_id, params )
      issues.each do |issue|
        # Before update checks if mapping still exist (no matter of labels- only projects mapping)
        unless issue.project.mappings.all( :conditions => ["tracker_project_id=?", tracker_project_id] ).empty?
          issue.update_attributes(params)
        end
      end
    end

    # Updates Redmine issues- status and owner when story restarted
    def story_restart(issues, activity)
      status = IssueStatus.find_by_name "Open"
      email = get_user_email( activity['project_id'], activity['author'] )
      author = User.find_by_mail email
      update_issues(issues, activity['project_id'], { :status_id => status.id, :assigned_to_id => author.id })
    end

    # Finishes the story when the Redmine issue is closed
    def finish_story(project_id, story_id)
      begin
        set_super_token
        story = PivotalTracker::Story.find(story_id, project_id)
        case story.story_type
          when 'feature'
            story.update( :current_state => 'finished' )
          when 'bug'
            story.update( :current_state => 'finished' )
          when 'chore'
            story.update( :current_state => 'accepted' )
        end
      rescue => e
        raise PivotalTrackerError.new("Can't finish the story id:#{story_id}. " + e )
      end
    end

    private

    # Gets and sets token for Pivotal Tracker 'Super User'
    def set_super_token
      set_token('super_user') if @token.nil?
    end

  end

  # Error to be raised when any problem occured while parsing activity data
  class WrongActivityData < StandardError; end;

  # Error to be raised when trackmine.yml can't be found in /config
  class MissingTrackmineConfig < StandardError; end;

  # Error to be raised when missing credentials for given email
  class MissingCredentials < StandardError; end;

  # Error to be raised when wrong credentials given
  class WrongCredentials < StandardError; end;

  # Error to be raised when missing Trackmine mapping.
  class MissingTrackmineMapping < StandardError; end;

  # Error to be raised when fails due to Trackmine configuration
  class WrongTrackmineConfiguration < StandardError; end;

  # Error to be raised when can't get access to PivotalTracker
  class PivotalTrackerError < StandardError; end;


end
