# frozen_string_literal: true

module API
  module Helpers
    module Packages
      module BasicAuthHelpers
        extend ::Gitlab::Utils::Override

        module Constants
          AUTHENTICATE_REALM_HEADER = 'Www-Authenticate: Basic realm'
          AUTHENTICATE_REALM_NAME = 'GitLab Packages Registry'
        end

        include Constants

        def unauthorized_user_project
          @unauthorized_user_project ||= find_project(params[:id])
        end

        def unauthorized_user_project!
          unauthorized_user_project || not_found!
        end

        def authorized_user_project
          @authorized_user_project ||= authorized_project_find!
        end

        def authorized_project_find!
          project = unauthorized_user_project

          unless project && can?(current_user, :read_project, project)
            return unauthorized_or! { not_found! }
          end

          project
        end

        def authorize!(action, subject = :global, reason = nil)
          return if can?(current_user, action, subject)

          unauthorized_or! { forbidden!(reason) }
        end

        def unauthorized_or!
          current_user ? yield : unauthorized!
        end

        override :unauthorized!
        def unauthorized!
          header(AUTHENTICATE_REALM_HEADER, AUTHENTICATE_REALM_NAME)
          super
        end
      end
    end
  end
end
