module Versioneye
  class Model

    require 'versioneye/log'

    require 'versioneye/models/api'
    require 'versioneye/models/api_call'
    require 'versioneye/models/billing_address'
    require 'versioneye/models/bitbucket_repo'
    require 'versioneye/models/circle_element'
    require 'versioneye/models/crawle'
    require 'versioneye/models/crawler_task'
    require 'versioneye/models/dependency'
    require 'versioneye/models/developer'
    require 'versioneye/models/error_message'
    require 'versioneye/models/event'
    require 'versioneye/models/email_setting'
    require 'versioneye/models/github_repo'
    require 'versioneye/models/json_cache'
    require 'versioneye/models/language'
    require 'versioneye/models/language_daily_stats'
    require 'versioneye/models/language_feed'
    require 'versioneye/models/license'
    require 'versioneye/models/license_whitelist'
    require 'versioneye/models/license_element'
    require 'versioneye/models/lottery'
    require 'versioneye/models/maven_repository'
    require 'versioneye/models/newest'
    require 'versioneye/models/notification'
    require 'versioneye/models/plan'
    require 'versioneye/models/product'
    require 'versioneye/models/product_resource'
    require 'versioneye/models/project'
    require 'versioneye/models/project_collaborator'
    require 'versioneye/models/projectdependency'
    require 'versioneye/models/promo_code'
    require 'versioneye/models/refer'
    require 'versioneye/models/receipt'
    require 'versioneye/models/repository'
    require 'versioneye/models/searchlog'
    require 'versioneye/models/security_notification'
    require 'versioneye/models/submitted_url'
    require 'versioneye/models/user'
    require 'versioneye/models/user_email'
    require 'versioneye/models/user_notification_setting'
    require 'versioneye/models/userlinkcollection'
    require 'versioneye/models/version'
    require 'versioneye/models/versionarchive'
    require 'versioneye/models/versioncomment'
    require 'versioneye/models/versioncommentreply'
    require 'versioneye/models/versionlink'
    require 'versioneye/models/global_setting'
    require 'versioneye/models/np_domain'
    require 'versioneye/models/reference'
    require 'versioneye/models/helpers/indexer'

    def self.log
      Versioneye::Log.instance.log
    end

    def log
      Versioneye::Log.instance.log
    end

  end
end
