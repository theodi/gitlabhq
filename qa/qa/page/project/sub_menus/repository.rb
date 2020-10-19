# frozen_string_literal: true

module QA
  module Page
    module Project
      module SubMenus
        module Repository
          extend QA::Page::PageConcern

          def self.included(base)
            super

            base.class_eval do
              include QA::Page::Project::SubMenus::Common

              view 'app/views/layouts/nav/sidebar/_project.html.haml' do
                element :repository_link
                element :branches_link
                element :tags_link
              end
            end
          end

          def click_repository
            within_sidebar do
              click_element(:repository_link)
            end
          end

          def go_to_repository_branches
            hover_repository do
              within_submenu do
                click_element(:branches_link)
              end
            end
          end

          def go_to_repository_tags
            hover_repository do
              within_submenu do
                click_element(:tags_link)
              end
            end
          end

          private

          def hover_repository
            within_sidebar do
              find_element(:repository_link).hover

              yield
            end
          end
        end
      end
    end
  end
end
