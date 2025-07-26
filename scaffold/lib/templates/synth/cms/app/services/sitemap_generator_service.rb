# frozen_string_literal: true

class SitemapGeneratorService
  def initialize
    @host = Rails.application.config.cms.sitemap_host
  end

  def generate
    builder = Nokogiri::XML::Builder.new(encoding: 'UTF-8') do |xml|
      xml.urlset(xmlns: 'http://www.sitemaps.org/schemas/sitemap/0.9',
                 'xmlns:news': 'http://www.google.com/schemas/sitemap-news/0.9',
                 'xmlns:xhtml': 'http://www.w3.org/1999/xhtml',
                 'xmlns:mobile': 'http://www.google.com/schemas/sitemap-mobile/1.0',
                 'xmlns:image': 'http://www.google.com/schemas/sitemap-image/1.1',
                 'xmlns:video': 'http://www.google.com/schemas/sitemap-video/1.1') do
        
        # Home page
        add_url(xml, @host, Time.current, 'daily', 1.0)
        
        # Blog index
        add_url(xml, "#{@host}/blog", Time.current, 'daily', 0.9)
        
        # Published posts
        Post.published.includes(:seo_metadata).find_each do |post|
          add_url(xml, 
                  "#{@host}/blog/#{post.slug}",
                  post.updated_at,
                  'weekly',
                  0.8,
                  post)
        end
        
        # Published pages
        Page.published.includes(:seo_metadata).find_each do |page|
          add_url(xml,
                  "#{@host}/#{page.slug}",
                  page.updated_at,
                  'monthly',
                  0.7,
                  page)
        end
        
        # Categories with published posts
        Category.joins(:posts)
                .where(posts: { published: true })
                .distinct
                .find_each do |category|
          add_url(xml,
                  "#{@host}/blog/category/#{category.slug}",
                  category.posts.published.maximum(:updated_at),
                  'weekly',
                  0.6)
        end
        
        # Tags with published posts
        Tag.joins(:posts)
           .where(posts: { published: true })
           .distinct
           .find_each do |tag|
          add_url(xml,
                  "#{@host}/blog/tag/#{tag.slug}",
                  tag.posts.published.maximum(:updated_at),
                  'weekly',
                  0.5)
        end
      end
    end
    
    builder.to_xml
  end

  def generate_to_file(path = nil)
    path ||= Rails.root.join('public', 'sitemap.xml')
    
    File.write(path, generate)
    path
  end

  private

  def add_url(xml, loc, lastmod = nil, changefreq = 'weekly', priority = 0.5, content = nil)
    xml.url do
      xml.loc loc
      xml.lastmod lastmod.iso8601 if lastmod
      xml.changefreq changefreq
      xml.priority priority
      
      # Add news sitemap data for recent blog posts
      if content.is_a?(Post) && content.published_at > 2.days.ago
        xml['news'].news do
          xml['news'].publication do
            xml['news'].name Rails.application.class.module_parent_name
            xml['news'].language 'en'
          end
          xml['news'].publication_date content.published_at.iso8601
          xml['news'].title content.title
        end
      end
      
      # Add images if content has them
      if content&.respond_to?(:content) && content.content.present?
        add_images(xml, content)
      end
    end
  end

  def add_images(xml, content)
    # Extract images from ActionText content
    content.content.embeds.each do |embed|
      if embed.respond_to?(:url) && image_url?(embed.url)
        xml['image'].image do
          xml['image'].loc embed.url
          xml['image'].title content.title if content.respond_to?(:title)
          xml['image'].caption embed.alt if embed.respond_to?(:alt) && embed.alt.present?
        end
      end
    end
  rescue
    # Fail silently if image extraction fails
  end

  def image_url?(url)
    url.present? && url.match?(/\.(jpg|jpeg|png|gif|webp|svg)$/i)
  end
end