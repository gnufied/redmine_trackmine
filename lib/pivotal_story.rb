class PivotalStory
  attr_accessor :issue, :pivotal_project_id

  def initialize(issue, pivotal_project_id)
    self.issue = issue
    self.pivotal_project_id = pivotal_project_id

    Trackmine.set_token(User.current.mail)

    tracker_project = PivotalTracker::Project.find pivotal_project_id

    story = tracker_project.stories.create(
      :story_type => story_type,
      :name => subject,
      :description => description
    )
    issue.custom_field_values = {pivotal_project_field_id => pivotal_project_id.to_s, pivotal_story_field_id => story.id.to_s}
  end

  def pivotal_project_field_id
    CustomField.find_by_name("Pivotal Project ID").id.to_s
  end

  def pivotal_story_field_id
    CustomField.find_by_name("Pivotal Story ID").id.to_s
  end

  def story_type
    case issue.tracker.name
      when 'Todo', 'Feature'
        'feature'
      when 'Defect', 'Bug'
        'bug'
      else
        'chore'
    end
  end

  def subject
    issue.subject + "(##{issue.id})"
  end

  def description
    issue.description + "\n" + " Linked to https://projects.brightbox.co.uk/issues/#{issue.id}"
  end

  def mapping
    @mapping ||= issue.project.mappings.first
  end

end
