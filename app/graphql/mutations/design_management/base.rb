# frozen_string_literal: true

module Mutations
  module DesignManagement
    class Base < ::Mutations::BaseMutation
      include Mutations::ResolvesIssuable

      argument :project_path, GraphQL::ID_TYPE,
               required: true,
               description: "The project where the issue is to upload designs for"

      argument :iid, GraphQL::ID_TYPE,
               required: true,
               description: "The iid of the issue to modify designs for"

      private

      def find_object(project_path:, iid:)
        resolve_issuable(type: :issue, parent_path: project_path, iid: iid)
      end
    end
  end
end
