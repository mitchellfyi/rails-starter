# CMS Module

This module provides a complete content management system with blog functionality, SEO optimization, and content publishing features using ActionText.

## Features

- **ActionText Integration**: Rich text editing with file attachments
- **SEO Optimization**: Meta tags, structured data, sitemaps
- **Content Publishing**: Draft/publish workflow with scheduling
- **Categorization**: Categories and tags for content organization
- **Featured Content**: Featured posts and images
- **RSS Feeds**: Automatic RSS feed generation
- **Friendly URLs**: SEO-friendly slugs with FriendlyId

## Installation

```bash
bin/synth add cms
```

This installs:
- ActionText for rich content editing
- Post and Category models with associations
- SEO helpers and meta-tags integration
- Sitemap and RSS feed generators
- Admin controllers for content management

## Post-Installation

1. **Run migrations:**
   ```bash
   rails db:migrate
   ```

2. **Add routes:**
   ```ruby
   resources :posts, only: [:index, :show] do
     collection do
       get :feed, defaults: { format: :rss }
     end
   end
   resources :categories, only: [:index, :show]
   
   namespace :admin do
     resources :posts
     resources :categories
   end
   ```

3. **Include concerns in models:**
   ```ruby
   # app/models/post.rb
   class Post < ApplicationRecord
     include PostPublishing
   end
   ```

4. **Set up meta-tags in layout:**
   ```erb
   <!-- app/views/layouts/application.html.erb -->
   <%= display_meta_tags %>
   ```

## Usage

### Creating Posts
```ruby
post = Post.create!(
  title: "Getting Started with AI",
  content: "Rich text content with ActionText...",
  excerpt: "Learn the basics of AI integration",
  author: current_user,
  published: true,
  published_at: Time.current,
  tag_list: ["ai", "tutorial", "rails"]
)

# Add featured image
post.featured_image.attach(params[:featured_image])
```

### SEO Configuration
```erb
<!-- In your view -->
<% set_meta_tags(
  title: @post.seo_title,
  description: @post.seo_description,
  keywords: page_keywords(@post.tag_list),
  image_src: @post.featured_image_url(:large)
) %>

<!-- Structured data -->
<script type="application/ld+json">
  <%= structured_data_for_post(@post).html_safe %>
</script>
```

### Content Queries
```ruby
# Published posts
Post.published.recent.limit(10)

# Posts by category
Post.by_category('tutorials').published

# Featured posts
Post.featured.published.limit(3)

# Posts by tag
Post.by_tag('rails').published
```

### Generating Sitemaps
```ruby
# In a rake task or job
SitemapGenerator.generate

# Schedule with cron or Sidekiq
class SitemapGeneratorJob < ApplicationJob
  def perform
    SitemapGenerator.generate
  end
end
```

### RSS Feeds
The module automatically provides RSS feeds at `/posts/feed.rss`

## Admin Interface

Admin controllers are provided for managing:
- Posts (create, edit, publish, feature)
- Categories (organize content)
- Tags (through acts_as_taggable_on)

## Customization

### Custom Post Types
Extend the Post model or create new content types:

```ruby
class Page < ApplicationRecord
  include PostPublishing
  # Custom page-specific logic
end
```

### SEO Customization
Override SEO helpers for custom meta tag handling:

```ruby
module CustomSeoHelper
  include SeoHelper
  
  def custom_meta_tags_for(content)
    # Your custom logic
  end
end
```

## Security

- User authentication required for admin actions
- File upload validation for featured images
- XSS protection via ActionText sanitization

## Testing

```bash
bin/synth test cms
```

## Version

Current version: 1.0.0