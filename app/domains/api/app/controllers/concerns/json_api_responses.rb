# frozen_string_literal: true

module JsonApiResponses
  extend ActiveSupport::Concern

  private

  def render_jsonapi_resource(resource, serializer_class = nil, status: :ok, meta: {}, include: [])
    serializer_class ||= "#{resource.class.name}Serializer".constantize
    
    serializer = serializer_class.new(resource, include: include, meta: meta)
    render json: serializer.serializable_hash, status: status
  end

  def render_jsonapi_collection(resources, serializer_class = nil, status: :ok, meta: {}, include: [], pagination: {})
    serializer_class ||= "#{resources.model.name}Serializer".constantize
    
    # Add pagination meta if provided
    combined_meta = meta.merge(pagination)
    
    # Generate pagination links for paginated collections
    links = if resources.respond_to?(:current_page)
      pagination_links(resources)
    else
      {}
    end
    
    serializer_options = { include: include, meta: combined_meta }
    serializer_options[:links] = links if links.any?
    
    serializer = serializer_class.new(resources, serializer_options)
    render json: serializer.serializable_hash, status: status
  end

  def render_jsonapi_error(status:, title:, detail: nil, code: nil, source: nil)
    error = {
      status: status.to_s,
      title: title
    }
    error[:detail] = detail if detail
    error[:code] = code if code
    error[:source] = source if source

    render json: { errors: [error] }, status: status
  end

  def render_jsonapi_errors(errors, status: :unprocessable_entity)
    formatted_errors = errors.map do |error|
      if error.is_a?(Hash)
        {
          status: status.to_s,
          title: 'Validation Error',
          detail: error[:detail] || error[:message],
          source: error[:source] || { pointer: "/data/attributes/#{error[:attribute]}" }
        }
      else
        {
          status: status.to_s,
          title: 'Validation Error',
          detail: error.to_s
        }
      end
    end

    render json: { errors: formatted_errors }, status: status
  end

  # Helper for paginated collections
  def pagination_meta(collection)
    return {} unless collection.respond_to?(:current_page)

    {
      pagination: {
        current_page: collection.current_page,
        per_page: collection.limit_value,
        total_pages: collection.total_pages,
        total_count: collection.total_count
      }
    }
  end
end