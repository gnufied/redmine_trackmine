class PivotalSync
  def self.sync(pivotal_project_id,redmine_project_id)
    Trackmine.set_token("super_user")
    new(pivotal_project_id,redmine_project_id)
  end

  attr_accessor :pivotal_project_id, :redmine_project_id

  def initialize(pivotal_project_id,redmine_project_id)
    @pivotal_project_id = pivotal_project_id
    @redmine_project_id = redmine_project_id

    @project = PivotalTracker::Project.find(pivotal_project_id)
    populate_already_synced_issues
  end

  def populate_already_synced_issues
    @synced_issues = @project.stories.all.inject([]) do |synced_issues,story|
      if story.name[/\(#(\d+)\)$/]
        synced_issues << $1.to_i
      end
      synced_issues
    end
  end

  def sync_all_open_issues
    issues = Project.find(redmine_project_id).issues.open
    issues.each do |issue|
      print "."
      next if @synced_issues.include(issue.id)
      PivotalStory.new(issue,pivotal_project_id)
    end
    puts "All issues synced up"
  end

end
