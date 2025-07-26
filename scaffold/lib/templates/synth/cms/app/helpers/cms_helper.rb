# frozen_string_literal: true

module CmsHelper
  def seo_meta_tags(content = nil)
    seo_data = extract_seo_data(content)
    
    content_tag_string = []
    
    # Basic meta tags
    content_tag_string << tag.title(seo_data[:title])
    content_tag_string << tag.meta(name: 'description', content: seo_data[:description])
    content_tag_string << tag.meta(name: 'keywords', content: seo_data[:keywords]) if seo_data[:keywords].present?
    
    # Robots meta tag
    content_tag_string << tag.meta(name: 'robots', content: seo_data[:robots])
    
    # Canonical URL
    content_tag_string << tag.link(rel: 'canonical', href: seo_data[:canonical_url]) if seo_data[:canonical_url].present?
    
    # Open Graph tags
    content_tag_string << tag.meta(property: 'og:title', content: seo_data[:og_title])
    content_tag_string << tag.meta(property: 'og:description', content: seo_data[:og_description])
    content_tag_string << tag.meta(property: 'og:type', content: seo_data[:og_type])
    content_tag_string << tag.meta(property: 'og:url', content: request.original_url)
    content_tag_string << tag.meta(property: 'og:image', content: seo_data[:og_image]) if seo_data[:og_image].present?
    
    # Twitter Card tags
    content_tag_string << tag.meta(name: 'twitter:card', content: 'summary_large_image')
    content_tag_string << tag.meta(name: 'twitter:title', content: seo_data[:og_title])
    content_tag_string << tag.meta(name: 'twitter:description', content: seo_data[:og_description])
    content_tag_string << tag.meta(name: 'twitter:image', content: seo_data[:og_image]) if seo_data[:og_image].present?
    
    safe_join(content_tag_string, "\n")
  end

  def structured_data_for(content)
    return '' unless content&.respond_to?(:seo_metadata) && content.seo_metadata.present?
    
    data = content.seo_metadata.structured_data
    return '' if data.empty?
    
    content_tag :script, type: 'application/ld+json' do
      raw data.to_json
    end
  end

  def reading_time(content)
    return '' unless content.respond_to?(:reading_time) && content.reading_time.present?
    
    pluralize(content.reading_time, 'minute') + ' read'
  end

  def format_post_date(post)
    return '' unless post.published_at.present?
    
    content_tag :time, datetime: post.published_at.iso8601 do
      post.published_at.strftime('%B %d, %Y')
    end
  end

  def post_status_badge(post)
    if post.published?
      content_tag :span, 'Published', class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-green-100 text-green-800'
    else
      content_tag :span, 'Draft', class: 'inline-flex items-center px-2.5 py-0.5 rounded-full text-xs font-medium bg-gray-100 text-gray-800'
    end
  end

  def category_link(category, options = {})
    return '' unless category.present?
    
    link_to category.name, blog_category_path(category.slug), 
            { class: 'text-blue-600 hover:text-blue-800' }.merge(options)
  end

  def tag_links(tags, options = {})
    return '' unless tags.present?
    
    tag_elements = tags.map do |tag|
      link_to "##{tag.name}", blog_tag_path(tag.slug),
              { class: 'inline-block bg-gray-100 text-gray-800 text-sm px-2 py-1 rounded hover:bg-gray-200' }.merge(options)
    end
    
    safe_join(tag_elements, ' ')
  end

  def breadcrumbs(items = [])
    return '' unless items.present?
    
    content_tag :nav, class: 'flex mb-6', 'aria-label': 'Breadcrumb' do
      content_tag :ol, class: 'inline-flex items-center space-x-1 md:space-x-3' do
        breadcrumb_items = items.map.with_index do |item, index|
          content_tag :li, class: 'inline-flex items-center' do
            if index > 0
              content = content_tag(:span, '/', class: 'mx-2 text-gray-400')
            else
              content = ''
            end
            
            if item[:path] && index < items.length - 1
              content += link_to(item[:name], item[:path], class: 'text-gray-700 hover:text-gray-900')
            else
              content += content_tag(:span, item[:name], class: 'text-gray-500')
            end
            
            raw content
          end
        end
        
        safe_join(breadcrumb_items)
      end
    end
  end

  def truncate_html(text, options = {})
    length = options[:length] || 150
    omission = options[:omission] || '...'
    
    return '' if text.blank?
    
    # Convert to plain text first, then truncate
    plain_text = strip_tags(text)
    truncate(plain_text, length: length, omission: omission)
  end

  def share_buttons(content, options = {})
    return '' unless content.present?
    
    url = options[:url] || request.original_url
    title = options[:title] || content.try(:title) || 'Check this out'
    
    content_tag :div, class: 'flex space-x-3' do
      buttons = []
      
      # Twitter
      twitter_url = "https://twitter.com/intent/tweet?url=#{CGI.escape(url)}&text=#{CGI.escape(title)}"
      buttons << link_to('Share on Twitter', twitter_url, 
                        class: 'bg-blue-500 text-white px-4 py-2 rounded hover:bg-blue-600',
                        target: '_blank', rel: 'noopener')
      
      # Facebook
      facebook_url = "https://www.facebook.com/sharer/sharer.php?u=#{CGI.escape(url)}"
      buttons << link_to('Share on Facebook', facebook_url,
                        class: 'bg-blue-600 text-white px-4 py-2 rounded hover:bg-blue-700',
                        target: '_blank', rel: 'noopener')
      
      # LinkedIn
      linkedin_url = "https://www.linkedin.com/sharing/share-offsite/?url=#{CGI.escape(url)}"
      buttons << link_to('Share on LinkedIn', linkedin_url,
                        class: 'bg-blue-700 text-white px-4 py-2 rounded hover:bg-blue-800',
                        target: '_blank', rel: 'noopener')
      
      safe_join(buttons)
    end
  end

  private

  def extract_seo_data(content)
    defaults = {
      title: 'Default Page Title',
      description: Rails.application.config.cms.default_meta_description,
      keywords: '',
      robots: 'index, follow',
      canonical_url: request.original_url,
      og_title: 'Default Page Title',
      og_description: Rails.application.config.cms.default_meta_description,
      og_type: 'website',
      og_image: nil
    }

    if content&.respond_to?(:seo_metadata) && content.seo_metadata.present?
      seo = content.seo_metadata
      {
        title: seo.meta_title.presence || content.try(:title) || defaults[:title],
        description: seo.meta_description.presence || content.try(:excerpt_or_content) || defaults[:description],
        keywords: seo.meta_keywords.presence || defaults[:keywords],
        robots: seo.robots_content,
        canonical_url: seo.canonical_url_or_default,
        og_title: seo.og_title_or_default,
        og_description: seo.og_description_or_default,
        og_type: seo.og_type,
        og_image: seo.og_image_url
      }
    elsif content.present?
      {
        title: content.try(:title) || @page_title || defaults[:title],
        description: content.try(:excerpt_or_content) || @page_description || defaults[:description],
        keywords: defaults[:keywords],
        robots: defaults[:robots],
        canonical_url: defaults[:canonical_url],
        og_title: content.try(:title) || @page_title || defaults[:og_title],
        og_description: content.try(:excerpt_or_content) || @page_description || defaults[:og_description],
        og_type: content.is_a?(Post) ? 'article' : 'website',
        og_image: nil
      }
    else
      defaults.merge(
        title: @page_title || defaults[:title],
        description: @page_description || defaults[:description],
        og_title: @page_title || defaults[:og_title],
        og_description: @page_description || defaults[:og_description]
      )
    end
  end
end