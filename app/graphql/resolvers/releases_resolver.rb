# frozen_string_literal: true

module Resolvers
  class ReleasesResolver < BaseResolver
    type Types::ReleaseType.connection_type, null: true

    alias_method :project, :object

    # This resolver has a custom singular resolver
    def self.single
      Resolvers::ReleaseResolver
    end

    def resolve(**args)
      return unless Feature.enabled?(:graphql_release_data, project, default_enabled: true)

      ReleasesFinder.new(
        project,
        current_user
      ).execute
    end
  end
end
