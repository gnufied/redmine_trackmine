class PivotalStory
  attr_accessor :issue, :pivotal_project_id

  def initialize(issue, pivotal_project_id)
    self.issue = issue
    self.pivotal_project_id = pivotal_project_id

    Trackmine.set_token(User.current.mail)

    tracker_project = PivotalTracker::Project.find pivotal_project_id

    story = tracker_project.stories.create(
      :story_type => story_type,
      :name => issue.subject,
      :description => description
    )
    issue.custom_field_values = {'1' => pivotal_project_id.to_s, '2' => story.id.to_s}
  end

  def story_type
    map_type = mapping.story_types.detect { |pt_type, mine_type| mine_type == issue.tracker.name }
    mapping[0]
  rescue
    'feature'
  end

  def description
    issue.description
  end

  def mapping
    @mapping ||= issue.project.mappings.first
  end

end