class ProjectService < Versioneye::Service


  def self.type_by_filename filename
    return nil if filename.to_s.empty?
    trimmed_name = filename.split('?')[0]
    return Project::A_TYPE_RUBYGEMS  if (!(/Gemfile$/ =~ trimmed_name).nil?)        or (!(/Gemfile.lock$/  =~ trimmed_name).nil?)
    return Project::A_TYPE_COMPOSER  if (!(/composer.json$/ =~ trimmed_name).nil?)  or (!(/composer.lock$/ =~ trimmed_name).nil?)
    return Project::A_TYPE_PIP       if (!(/requirements.txt$/ =~ trimmed_name).nil?)  or (!(/setup.py$/ =~ trimmed_name).nil?) or (!(/pip.log$/ =~ trimmed_name).nil?)
    return Project::A_TYPE_NPM       if (!(/package.json$/ =~ trimmed_name).nil?)
    return Project::A_TYPE_GRADLE    if (!(/.gradle$/ =~ trimmed_name).nil?)
    return Project::A_TYPE_MAVEN2    if (!(/pom.xml$/ =~ trimmed_name).nil?)  or (!(/pom.json$/ =~ trimmed_name).nil?)
    return Project::A_TYPE_LEIN      if (!(/project.clj$/ =~ trimmed_name).nil?)
    return Project::A_TYPE_BOWER     if (!(/bower.json$/ =~ trimmed_name).nil?)
    return Project::A_TYPE_COCOAPODS if (!(/Podfile$/ =~ trimmed_name).nil?)  or (!(/.podfile$/ =~ trimmed_name).nil?) or (!(/Podfile.lock$/ =~ trimmed_name).nil?)
    return nil
  end


  def self.find id
    project = Project.find_by_id( id )
    return nil if project.nil?

    project.dependencies.each do |dep|
      ProjectdependencyService.outdated?( dep )
    end
    project
  end


  def self.store project
    return false if project.nil?

    project.make_project_key!
    if project.dependencies && !project.dependencies.empty? && project.save
      project.save_dependencies
      return true
    else
      log.error "Can't save project: #{project.errors.full_messages.to_json}"
      return false
    end
  end


  def self.destroy project_id
    project = Project.find_by_id( project_id )
    return false if project.nil?

    project.remove_dependencies
    project.remove_collaborators
    project.remove
  end


  # Returns a map with
  #  - :key => "language_prod_key"
  #  - :value => "Array of project IDs where the prod_key is used"
  def self.user_product_index_map user, add_collaborated = true
    indexes = Hash.new
    projects = user.projects
    return indexes if projects.nil?

    projects.each do |project|
      next if project.nil?
      project.dependencies.each do |dep|
        next if dep.nil? or dep.product.nil?
        product = dep.product
        prod_id = "#{product.language_esc}_#{product.prod_key}"
        indexes[prod_id] = [] unless indexes.has_key?(prod_id)
        indexes[prod_id] << project[:_id].to_s
      end
    end

    collaborated_projects = Project.by_collaborator(user)
    if add_collaborated and !collaborated_projects.nil?
      collaborated_projects.each do |project|
        next if project.nil?
        project.dependencies.each do |dep|
          next if dep.nil? or dep.product.nil?
          product = dep.product
          prod_id = "#{product.language_esc}_#{product.prod_key}"
          indexes[prod_id] = [] unless indexes.has_key?(prod_id)
          indexes[prod_id] << project[:_id].to_s
        end
      end
    end

    indexes
  end


  def self.badge_for_project project_id
    log.debug "project_id: #{project_id}"
    badge = cache.get project_id.to_s
    log.info "badge: #{badge}"
    return badge if badge

    project = Project.find_by_id project_id.to_s
    return "unknown" if project.nil?

    update_badge_for_project project
  end


  def self.update_badge_for_project project
    badge    = outdated?(project) ? 'out-of-date' : 'up-to-date'
    cache.set( project.id.to_s, badge, 21600) # TTL = 6.hour
    badge
  rescue => e
    log.error e.message
    log.error e.backtrace.join "\n"
    "unknown"
  end


  def self.outdated?( project )
    project.projectdependencies.each do |dep|
      return true if ProjectdependencyService.outdated?( dep )
    end
    false
  end

  def self.outdated_dependencies( project )
    outdated_dependencies = Array.new
    project.projectdependencies.each do |dep|
      outdated_dependencies << dep if ProjectdependencyService.outdated?( dep )
    end
    outdated_dependencies
  end

end
