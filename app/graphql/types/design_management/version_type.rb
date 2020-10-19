# frozen_string_literal: true

module Types
  module DesignManagement
    class VersionType < ::Types::BaseObject
      # Just `Version` might be a bit to general to expose globally so adding
      # a `Design` prefix to specify the class exposed in GraphQL
      graphql_name 'DesignVersion'

      description 'A specific version in which designs were added, modified or deleted'

      authorize :read_design

      field :id, GraphQL::ID_TYPE, null: false,
            description: 'ID of the design version'
      field :sha, GraphQL::ID_TYPE, null: false,
            description: 'SHA of the design version'

      field :designs,
            ::Types::DesignManagement::DesignType.connection_type,
            null: false,
            description: 'All designs that were changed in the version'

      field :designs_at_version,
            ::Types::DesignManagement::DesignAtVersionType.connection_type,
            null: false,
            description: 'All designs that are visible at this version, as of this version',
            resolver: ::Resolvers::DesignManagement::Version::DesignsAtVersionResolver

      field :design_at_version,
            ::Types::DesignManagement::DesignAtVersionType,
            null: false,
            description: 'A particular design as of this version, provided it is visible at this version',
            resolver: ::Resolvers::DesignManagement::Version::DesignsAtVersionResolver.single
    end
  end
end
