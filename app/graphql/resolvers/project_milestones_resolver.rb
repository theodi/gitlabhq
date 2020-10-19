# frozen_string_literal: true

module Resolvers
  class ProjectMilestonesResolver < MilestonesResolver
    argument :include_ancestors, GraphQL::BOOLEAN_TYPE,
             required: false,
             description: "Also return milestones in the project's parent group and its ancestors"

    private

    def parent_id_parameters(args)
      return { project_ids: parent.id } unless args[:include_ancestors].present? && parent.group.present?

      {
        group_ids: parent.group.self_and_ancestors.select(:id),
        project_ids: parent.id
      }
    end
  end
end
