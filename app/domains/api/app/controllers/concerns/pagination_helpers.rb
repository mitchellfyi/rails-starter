# frozen_string_literal: true

module PaginationHelpers
  extend ActiveSupport::Concern

  private

  # Paginate collection and return with JSON:API meta information
  def paginate_collection(collection, per_page: 25)
    page = params[:page]&.fetch(:number, 1)&.to_i || 1
    per_page = params[:page]&.fetch(:size, per_page)&.to_i || per_page
    
    # Ensure reasonable limits
    per_page = [per_page, 100].min
    per_page = [per_page, 1].max
    
    paginated = collection.page(page).per(per_page)
    
    {
      collection: paginated,
      meta: pagination_meta(paginated)
    }
  end

  # Generate pagination links according to JSON:API spec
  def pagination_links(collection, base_url = request.base_url + request.path)
    return {} unless collection.respond_to?(:current_page)

    links = {}
    current_page = collection.current_page
    total_pages = collection.total_pages
    per_page = collection.limit_value

    # Self link
    links[:self] = paginated_url(base_url, current_page, per_page)

    # First and last
    links[:first] = paginated_url(base_url, 1, per_page)
    links[:last] = paginated_url(base_url, total_pages, per_page) if total_pages > 0

    # Previous and next
    if current_page > 1
      links[:prev] = paginated_url(base_url, current_page - 1, per_page)
    end

    if current_page < total_pages
      links[:next] = paginated_url(base_url, current_page + 1, per_page)
    end

    links
  end

  def paginated_url(base_url, page, per_page)
    uri = URI(base_url)
    query_params = Rack::Utils.parse_query(uri.query)
    query_params['page'] = { 'number' => page, 'size' => per_page }
    uri.query = query_params.to_query
    uri.to_s
  end
end