class PivotalStory
  attr_accessor :issue, :pivotal_project_id

  def initialize(issue, pivotal_project_id,pivotal_story_id = nil)
    self.issue = issue
    self.pivotal_project_id = pivotal_project_id

    Trackmine.set_token(User.current.mail)

    tracker_project = PivotalTracker::Project.find pivotal_project_id

    if pivotal_story_id
      update(tracker_project,pivotal_story_id)
    else
      create(tracker_project)
    end
  end

  def create(tracker_project)
    story = tracker_project.stories.create(
                                    :story_type => story_type,
                                    :name => subject,
                                    :description => description,
                                    :labels => project_label,
                                    :requested_by => requester(tracker_project)
                                    )

    issue.custom_field_values = {
      pivotal_project_field_id => pivotal_project_id.to_s,
      pivotal_story_field_id => story.id.to_s
    }
  end

  def requester(tracker_project)
    tracker_project.memberships.all.select { |m| m.email == issue.author.mail }[0].name
  end

  def update(tracker_project,pivotal_story_id)
    pivotal_story = tracker_project.stories.find(pivotal_story_id)
    pivotal_story.update(:requested_by => requester(tracker_project))
    
    issue.custom_field_values = {
      pivotal_project_field_id => pivotal_project_id.to_s,
      pivotal_story_field_id => pivotal_story_id
    }
    issue.save!
  end

  def pivotal_project_field_id
    CustomField.find_by_name("Pivotal Project ID").id.to_s
  end

  def pivotal_story_field_id
    CustomField.find_by_name("Pivotal Story ID").id.to_s
  end

  def project_label
    issue.project.name
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
