# CMS Module - Content Management and Blog Engine

This module adds a comprehensive content management system and blog engine to your Rails app with ActionText, WYSIWYG editing, SEO optimization, and sitemap generation.

## Features

### 📝 Content Management
- **Post Model**: Blog posts with rich content via ActionText
- **Page Model**: Static pages with custom layouts
- **Category & Tag Models**: Hierarchical content organization
- **SEO Metadata**: Title, description, keywords for each piece of content
- **Slug-based URLs**: SEO-friendly routing with FriendlyId

### 🎨 Rich Text Editing
- **ActionText Integration**: Rails' built-in rich text editor
- **Trix WYSIWYG Editor**: Modern, accessible rich text editing
- **Image & Attachment Support**: Upload and embed media
- **Content Formatting**: Support for headings, lists, links, quotes

### 🔍 SEO Optimization
- **Meta Tags**: Automatic generation of meta title, description, keywords
- **Sitemap.xml**: Auto-generated sitemap for search engines
- **Structured Data**: Schema.org markup for better search visibility
- **Canonical URLs**: Prevent duplicate content issues
- **Open Graph**: Social media sharing optimization

### 👨‍💼 Admin Interface
- **Content Dashboard**: Overview of all posts and pages
- **WYSIWYG Editor**: User-friendly content creation
- **Category Management**: Hierarchical category organization
- **Tag Management**: Flexible tagging system
- **SEO Preview**: Preview how content appears in search results
- **Publishing Workflow**: Draft, review, publish states

### 🚀 Performance & Accessibility
- **Caching**: Fragment and page caching for performance
- **Responsive Design**: Mobile-first admin interface
- **Accessibility**: WCAG 2.1 AA compliant
- **Progressive Enhancement**: Works without JavaScript

## Installation

Run the following command from your application root:

```bash
bin/synth add cms
```

This installs:
- Post, Page, Category, Tag, and SeoMetadata models
- Admin controllers and views for content management
- Public controllers for blog and page display
- ActionText integration with Trix editor
- Sitemap generation service
- SEO optimization helpers
- Comprehensive test suite
- Sample content and categories

## Configuration

### ActionText Setup

The module automatically configures ActionText, but you may want to customize storage:

```ruby
# config/storage.yml
local:
  service: Disk
  root: <%= Rails.root.join("storage") %>
```

### SEO Configuration

Configure SEO defaults in an initializer:

```ruby
# config/initializers/cms.rb
Rails.application.config.cms = ActiveSupport::OrderedOptions.new
Rails.application.config.cms.default_meta_description = "Your site description"
Rails.application.config.cms.sitemap_host = "https://yourdomain.com"
Rails.application.config.cms.posts_per_page = 10
```

## Usage

### Creating Content

#### Blog Posts
```ruby
# Create a new blog post
post = Post.new(
  title: "Getting Started with Rails",
  content: "Rich text content here...",
  category: Category.find_by(name: "Tutorials"),
  tags: [Tag.find_or_create_by(name: "rails")],
  published: true
)

# Add SEO metadata
post.seo_metadata = SeoMetadata.new(
  meta_title: "Getting Started with Rails - Complete Guide",
  meta_description: "Learn Rails development from scratch with this comprehensive tutorial.",
  meta_keywords: "rails, ruby, tutorial, web development"
)

post.save!
```

#### Static Pages
```ruby
# Create a static page
page = Page.new(
  title: "About Us",
  content: "Rich text content about your company...",
  slug: "about",
  published: true
)

page.seo_metadata = SeoMetadata.new(
  meta_title: "About Us - Our Story",
  meta_description: "Learn about our company history and mission."
)

page.save!
```

### Admin Interface

Access the admin interface at `/admin/cms`:
- `/admin/cms/posts` - Manage blog posts
- `/admin/cms/pages` - Manage static pages
- `/admin/cms/categories` - Organize categories
- `/admin/cms/tags` - Manage tags

### Public URLs

Content is accessible via SEO-friendly URLs:
- `/blog` - Blog post listing
- `/blog/category/tutorials` - Posts in "Tutorials" category
- `/blog/tag/rails` - Posts tagged with "rails"
- `/blog/getting-started-with-rails` - Individual blog post
- `/about` - Static page

## Models

### Post
```ruby
class Post < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged
  
  has_rich_text :content
  belongs_to :category, optional: true
  has_many :post_tags, dependent: :destroy
  has_many :tags, through: :post_tags
  has_one :seo_metadata, as: :seo_optimizable, dependent: :destroy
  
  validates :title, presence: true
  validates :content, presence: true
  
  scope :published, -> { where(published: true) }
  scope :recent, -> { order(created_at: :desc) }
end
```

### Page
```ruby
class Page < ApplicationRecord
  extend FriendlyId
  friendly_id :title, use: :slugged
  
  has_rich_text :content
  has_one :seo_metadata, as: :seo_optimizable, dependent: :destroy
  
  validates :title, presence: true
  validates :content, presence: true
  validates :slug, presence: true, uniqueness: true
  
  scope :published, -> { where(published: true) }
end
```

### SeoMetadata
```ruby
class SeoMetadata < ApplicationRecord
  belongs_to :seo_optimizable, polymorphic: true
  
  validates :meta_title, presence: true, length: { maximum: 60 }
  validates :meta_description, presence: true, length: { maximum: 160 }
  validates :meta_keywords, length: { maximum: 255 }
end
```

## SEO Features

### Meta Tags Helper

The module provides helpers for generating SEO meta tags:

```erb
<!-- In your layout -->
<%= seo_meta_tags(@post) %>
```

### Sitemap Generation

Automatically generate sitemap.xml:

```ruby
# Generate sitemap
SitemapGenerator.new.generate

# Access sitemap
# GET /sitemap.xml
```

## Testing

The module includes comprehensive tests:

```bash
# Run all CMS tests
bin/rails test test/models/cms/
bin/rails test test/controllers/cms/
bin/rails test test/integration/cms/

# Run specific test module
bin/synth test cms
```

## Next Steps

After installation:

1. **Configure SEO Settings**: Update meta descriptions and sitemap host
2. **Customize Styling**: Adapt the admin interface to your brand
3. **Create Content**: Add your first blog posts and pages
4. **Test Performance**: Verify caching is working correctly
5. **Set up Analytics**: Track content performance