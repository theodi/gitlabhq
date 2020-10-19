# frozen_string_literal: true

class BulkCreateIntegrationService
  def initialize(integration, batch, association)
    @integration = integration
    @batch = batch
    @association = association
  end

  def execute
    service_list = ServiceList.new(batch, service_hash, association).to_array

    Service.transaction do
      results = bulk_insert(*service_list)

      if integration.data_fields_present?
        data_list = DataList.new(results, data_fields_hash, integration.data_fields.class).to_array

        bulk_insert(*data_list)
      end

      run_callbacks(batch) if association == 'project'
    end
  end

  private

  attr_reader :integration, :batch, :association

  def bulk_insert(klass, columns, values_array)
    items_to_insert = values_array.map { |array| Hash[columns.zip(array)] }

    klass.insert_all(items_to_insert, returning: [:id])
  end

  # rubocop: disable CodeReuse/ActiveRecord
  def run_callbacks(batch)
    if integration.issue_tracker?
      Project.where(id: batch.select(:id)).update_all(has_external_issue_tracker: true)
    end

    if integration.type == 'ExternalWikiService'
      Project.where(id: batch.select(:id)).update_all(has_external_wiki: true)
    end
  end
  # rubocop: enable CodeReuse/ActiveRecord

  def service_hash
    if integration.template?
      integration.to_service_hash
    else
      integration.to_service_hash.tap { |json| json['inherit_from_id'] = integration.id }
    end
  end

  def data_fields_hash
    integration.to_data_fields_hash
  end
end
