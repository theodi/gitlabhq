# frozen_string_literal: true

module Gitlab
  module Pagination
    class OffsetPagination < Base
      attr_reader :request_context
      delegate :params, :header, :request, to: :request_context

      def initialize(request_context)
        @request_context = request_context
      end

      def paginate(relation, exclude_total_headers: false)
        paginate_with_limit_optimization(add_default_order(relation)).tap do |data|
          add_pagination_headers(data, exclude_total_headers)
        end
      end

      private

      def paginate_with_limit_optimization(relation)
        # do not paginate relation if it is already paginated
        pagination_data = if relation.respond_to?(:current_page) && relation.current_page == params[:page] && relation.limit_value == params[:per_page]
                            relation
                          else
                            relation.page(params[:page]).per(params[:per_page])
                          end

        return pagination_data unless pagination_data.is_a?(ActiveRecord::Relation)
        return pagination_data unless Feature.enabled?(:api_kaminari_count_with_limit, type: :ops)

        limited_total_count = pagination_data.total_count_with_limit
        if limited_total_count > Kaminari::ActiveRecordRelationMethods::MAX_COUNT_LIMIT
          # The call to `total_count_with_limit` memoizes `@arel` because of a call to `references_eager_loaded_tables?`
          # We need to call `reset` because `without_count` relies on `@arel` being unmemoized
          pagination_data.reset.without_count
        else
          pagination_data
        end
      end

      def add_default_order(relation)
        if relation.is_a?(ActiveRecord::Relation) && relation.order_values.empty?
          relation = relation.order(:id) # rubocop: disable CodeReuse/ActiveRecord
        end

        relation
      end

      def add_pagination_headers(paginated_data, exclude_total_headers)
        header 'X-Per-Page',    paginated_data.limit_value.to_s
        header 'X-Page',        paginated_data.current_page.to_s
        header 'X-Next-Page',   paginated_data.next_page.to_s
        header 'X-Prev-Page',   paginated_data.prev_page.to_s
        header 'Link',          pagination_links(paginated_data)

        return if exclude_total_headers || data_without_counts?(paginated_data)

        header 'X-Total',       paginated_data.total_count.to_s
        header 'X-Total-Pages', total_pages(paginated_data).to_s
      end

      def pagination_links(paginated_data)
        [].tap do |links|
          links << %(<#{page_href(page: paginated_data.prev_page)}>; rel="prev") if paginated_data.prev_page
          links << %(<#{page_href(page: paginated_data.next_page)}>; rel="next") if paginated_data.next_page
          links << %(<#{page_href(page: 1)}>; rel="first")

          links << %(<#{page_href(page: total_pages(paginated_data))}>; rel="last") unless data_without_counts?(paginated_data)
        end.join(', ')
      end

      def total_pages(paginated_data)
        # Ensure there is in total at least 1 page
        [paginated_data.total_pages, 1].max
      end

      def data_without_counts?(paginated_data)
        paginated_data.is_a?(Kaminari::PaginatableWithoutCount)
      end

      def base_request_uri
        @base_request_uri ||= URI.parse(request.url).tap do |uri|
          uri.host = Gitlab.config.gitlab.host
          uri.port = Gitlab.config.gitlab.port
        end
      end

      def build_page_url(query_params:)
        base_request_uri.tap do |uri|
          uri.query = query_params
        end.to_s
      end

      def page_href(next_page_params = {})
        query_params = params.merge(**next_page_params, per_page: per_page).to_query

        build_page_url(query_params: query_params)
      end

      def per_page
        @per_page ||= params[:per_page]
      end
    end
  end
end
