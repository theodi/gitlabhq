# frozen_string_literal: true

class IssuableFinder
  class Params < SimpleDelegator
    include Gitlab::Utils::StrongMemoize

    # This is used as a common filter for None / Any
    FILTER_NONE = 'none'
    FILTER_ANY = 'any'

    # This is used in unassigning users
    NONE = '0'

    alias_method :params, :__getobj__

    attr_accessor :current_user, :klass

    def initialize(params, current_user, klass)
      @current_user = current_user
      @klass = klass
      # We turn the params into a HashWithIndifferentAccess. We must use #to_h first because sometimes
      # we get ActionController::Params and IssuableFinder::Params objects here.
      super(params.to_h.with_indifferent_access)
    end

    def present?
      params.present?
    end

    def author_id?
      params[:author_id].present? && params[:author_id] != NONE
    end

    def author_username?
      params[:author_username].present? && params[:author_username] != NONE
    end

    def no_author?
      # author_id takes precedence over author_username
      params[:author_id] == NONE || params[:author_username] == NONE
    end

    def filter_by_no_assignee?
      params[:assignee_id].to_s.downcase == FILTER_NONE
    end

    def filter_by_any_assignee?
      params[:assignee_id].to_s.downcase == FILTER_ANY
    end

    def filter_by_no_label?
      downcased = label_names.map(&:downcase)

      downcased.include?(FILTER_NONE)
    end

    def filter_by_any_label?
      label_names.map(&:downcase).include?(FILTER_ANY)
    end

    def labels?
      params[:label_name].present?
    end

    def milestones?
      params[:milestone_title].present?
    end

    def filter_by_no_milestone?
      # Accepts `No Milestone` for compatibility
      params[:milestone_title].to_s.downcase == FILTER_NONE || params[:milestone_title] == Milestone::None.title
    end

    def filter_by_any_milestone?
      # Accepts `Any Milestone` for compatibility
      params[:milestone_title].to_s.downcase == FILTER_ANY || params[:milestone_title] == Milestone::Any.title
    end

    def filter_by_upcoming_milestone?
      params[:milestone_title] == Milestone::Upcoming.name
    end

    def filter_by_started_milestone?
      params[:milestone_title] == Milestone::Started.name
    end

    def filter_by_no_release?
      params[:release_tag].to_s.downcase == FILTER_NONE
    end

    def filter_by_any_release?
      params[:release_tag].to_s.downcase == FILTER_ANY
    end

    def filter_by_no_reaction?
      params[:my_reaction_emoji].to_s.downcase == FILTER_NONE
    end

    def filter_by_any_reaction?
      params[:my_reaction_emoji].to_s.downcase == FILTER_ANY
    end

    def releases?
      params[:release_tag].present?
    end

    def project?
      project_id.present?
    end

    def group
      strong_memoize(:group) do
        if params[:group_id].is_a?(Group)
          params[:group_id]
        elsif params[:group_id].present?
          Group.find(params[:group_id])
        else
          nil
        end
      end
    end

    def related_groups
      if project? && project&.group && Ability.allowed?(current_user, :read_group, project.group)
        project.group.self_and_ancestors
      elsif group
        [group]
      elsif current_user
        Gitlab::ObjectHierarchy.new(current_user.authorized_groups, current_user.groups).all_objects
      else
        []
      end
    end

    def project
      strong_memoize(:project) do
        next nil unless project?

        project = project_id.is_a?(Project) ? project_id : Project.find(project_id)
        project = nil unless Ability.allowed?(current_user, :"read_#{klass.to_ability_name}", project)

        project
      end
    end

    def project_id
      params[:project_id]
    end

    def projects
      strong_memoize(:projects) do
        next [project] if project?

        projects =
          if current_user && params[:authorized_only].presence && !current_user_related?
            current_user.authorized_projects(min_access_level)
          else
            projects_public_or_visible_to_user
          end

        projects.with_feature_available_for_user(klass, current_user).reorder(nil) # rubocop: disable CodeReuse/ActiveRecord
      end
    end

    # rubocop: disable CodeReuse/ActiveRecord
    def author
      strong_memoize(:author) do
        if author_id?
          User.find_by(id: params[:author_id])
        elsif author_username?
          User.find_by_username(params[:author_username])
        else
          nil
        end
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    # rubocop: disable CodeReuse/ActiveRecord
    def assignees
      strong_memoize(:assignees) do
        if assignee_id?
          User.where(id: params[:assignee_id])
        elsif assignee_username?
          User.where(username: params[:assignee_username])
        else
          User.none
        end
      end
    end
    # rubocop: enable CodeReuse/ActiveRecord

    def assignee
      assignees.first
    end

    def label_names
      if labels?
        params[:label_name].is_a?(String) ? params[:label_name].split(',') : params[:label_name]
      else
        []
      end
    end

    def labels
      strong_memoize(:labels) do
        if labels? && !filter_by_no_label?
          LabelsFinder.new(current_user, project_ids: projects, title: label_names).execute(skip_authorization: true) # rubocop: disable CodeReuse/Finder
        else
          Label.none
        end
      end
    end

    def milestones
      strong_memoize(:milestones) do
        if milestones?
          if project?
            group_id = project.group&.id
            project_id = project.id
          end

          group_id = group.id if group

          search_params =
            { title: params[:milestone_title], project_ids: project_id, group_ids: group_id }

          MilestonesFinder.new(search_params).execute # rubocop: disable CodeReuse/Finder
        else
          Milestone.none
        end
      end
    end

    def current_user_related?
      scope = params[:scope]
      scope == 'created_by_me' || scope == 'authored' || scope == 'assigned_to_me'
    end

    def find_group_projects
      return Project.none unless group

      if params[:include_subgroups]
        Project.where(namespace_id: group.self_and_descendants) # rubocop: disable CodeReuse/ActiveRecord
      else
        group.projects
      end
    end

    # We use Hash#merge in a few places, so let's support it
    def merge(other)
      self.class.new(params.merge(other), current_user, klass)
    end

    # Just for symmetry, and in case someone tries to use it
    def merge!(other)
      params.merge!(other)
    end

    private

    def projects_public_or_visible_to_user
      projects =
        if group
          if params[:projects]
            find_group_projects.id_in(params[:projects])
          else
            find_group_projects
          end
        elsif params[:projects]
          Project.id_in(params[:projects])
        else
          Project
        end

      projects.public_or_visible_to_user(current_user, min_access_level)
    end

    def min_access_level
      ProjectFeature.required_minimum_access_level(klass)
    end

    def method_missing(method_name, *args, &block)
      if method_name[-1] == '?'
        params[method_name[0..-2].to_sym].present?
      else
        super
      end
    end

    def respond_to_missing?(method_name, include_private = false)
      method_name[-1] == '?'
    end
  end
end
