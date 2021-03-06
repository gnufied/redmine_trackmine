class PivotalSync
  def self.sync(pivotal_project_id,redmine_project_id)
    Trackmine.set_token("super_user")
    new(pivotal_project_id,redmine_project_id)
  end

  attr_accessor :pivotal_project_id, :redmine_project_handle

  def initialize(pivotal_project_id,redmine_project_handle)
    if pivotal_project_id.blank? || redmine_project_handle.blank?
      raise "Please specify redmine_project_[id|name] and pivotal_project_id as command line argument"
    end

    @pivotal_project_id = pivotal_project_id
    @redmine_project_handle = redmine_project_handle

    @project = PivotalTracker::Project.find(pivotal_project_id)
    raise "Invalid pivotal project id #{pivotal_project_id}" unless @project
    populate_already_synced_issues
    sync_all_open_issues
  end

  def populate_already_synced_issues
    @synced_issues = @project.stories.all.inject({}) do |synced_issues,story|
      if story.name[/\(#(\d+)\)$/]
        synced_issues[$1.to_i] = story
      end
      synced_issues
    end
  end

  def redmine_project
    Project.find_by_id(redmine_project_handle) ||
      Project.find_by_name(redmine_project_handle)
  end

  def sync_all_open_issues
    project = redmine_project()
    raise "Invalid redmine project #{redmine_project_handle}" unless project
    $stdout.sync = true
    issues = project.issues.open
    issues.each do |issue|
      pivotal_story = @synced_issues[issue.id]
      sync_issue(issue,pivotal_project_id,pivotal_story)
      $stdout.print "."
    end
    puts "All issues synced up"
  end

  def sync_issue(issue,pivotal_project_id,pivotal_story)
    if pivotal_story
      PivotalStory.new(issue,pivotal_project_id,pivotal_story.id.to_s)
    else
      PivotalStory.new(issue,pivotal_project_id)
    end
    issue.save!
  rescue
    puts "Failed to sync ticket #{issue.id}"
  end

end
