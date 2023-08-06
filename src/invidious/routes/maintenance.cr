{% skip_file if flag?(:api_only) %}

module Invidious::Routes::MaintenanceRoute
  def self.flushvidcache(env)
    referer = get_referer(env)

    if env.get?("user") && CONFIG.admins.includes? env.get?("user").as(Invidious::User).email
      Invidious::Database::Videos.delete_all
      env.redirect referer
    else
      return error_template(403, "You are not allowed to perform this action.")
    end
  end
end
