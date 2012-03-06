desc "Sync all open tickets to pivotal"
task :sync_tickets do
  redmine_project_id = ENV['redmine_project_id']
  pivotal_project_id = ENV['pivotal_project_id']
  PivotalSync.sync(pivotal_project_id,redmine_project_id)
end
