# frozen_string_literal: true

module QA
  module Page
    module Project
      module Fork
        class New < Page::Base
          view 'app/views/projects/forks/_fork_button.html.haml' do
            element :fork_namespace_button
          end

          def choose_namespace(namespace = Runtime::Namespace.path)
            click_element(:fork_namespace_button, name: namespace)
          end
        end
      end
    end
  end
end
