# frozen_string_literal: true

module QA
  module Page
    module Group
      class Menu < Page::Base
        include SubMenus::Common

        view 'app/views/layouts/nav/sidebar/_group.html.haml' do
          element :general_settings_link
          element :group_issues_item
          element :group_members_item
          element :group_milestones_link
          element :group_settings_item
        end

        view 'app/views/layouts/nav/sidebar/_analytics_links.html.haml' do
          element :analytics_link
          element :analytics_sidebar_submenu
        end

        def click_group_members_item
          within_sidebar do
            click_element(:group_members_item)
          end
        end

        def click_settings
          within_sidebar do
            click_element(:group_settings_item)
          end
        end

        def click_contribution_analytics_item
          hover_element(:analytics_link) do
            within_submenu(:analytics_sidebar_submenu) do
              click_element(:contribution_analytics_link)
            end
          end
        end

        def click_group_general_settings_item
          hover_element(:group_settings_item) do
            within_submenu(:group_sidebar_submenu) do
              click_element(:general_settings_link)
            end
          end
        end

        def go_to_milestones
          hover_issues do
            within_submenu do
              click_element(:group_milestones_link)
            end
          end
        end

        private

        def hover_issues
          within_sidebar do
            scroll_to_element(:group_issues_item)
            find_element(:group_issues_item).hover

            yield
          end
        end
      end
    end
  end
end

QA::Page::Group::Menu.prepend_if_ee('QA::EE::Page::Group::Menu')
