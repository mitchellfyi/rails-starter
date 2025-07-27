# CMS Module Demonstration

This document demonstrates the CMS/blog engine functionality that would be available after installing the module.

## Installation

In a Rails application with the starter template:

```bash
bin/synth add cms
rails db:migrate
```

## Models Created

### Cms::Post
- Rich text content with ActionText
- SEO metadata (title, description, keywords)
- Friendly URLs with slugs
- Categories and tags
- Published/draft states
- View counting
- Featured posts support

### Cms::Page
- Static page content with ActionText
- SEO metadata
- Custom templates
- Friendly URLs
- Position ordering

### Cms::Category
- Hierarchical categories
- SEO optimization
- Friendly URLs

### Cms::Tag
- Simple tagging system
- Color coding
- Friendly URLs

## Admin Interface Features

### Posts Management (`/admin/posts`)
- WYSIWYG editor with ActionText
- Rich media embedding (images, videos, files)
- Category assignment
- Tag management
- SEO metadata editing
- Draft/published states
- Featured post flagging
- Scheduled publishing

### Pages Management (`/admin/pages`)
- Static page creation
- Custom template assignment
- Position ordering
- SEO optimization

### Categories & Tags (`/admin/categories`, `/admin/tags`)
- Hierarchical category management
- Tag creation and organization
- Color coding for tags

## Public Interface Features

### Blog (`/blog`)
- Paginated post listing
- Category filtering
- Tag filtering
- Responsive design
- SEO optimized

### Individual Posts (`/blog/post-slug`)
- Full post content
- Related categories and tags
- Social sharing ready
- Schema.org markup

### Static Pages (`/page-slug`)
- Custom page content
- Template support

## SEO Features

### Meta Tags
- Automatic meta title and description
- Open Graph tags
- Twitter Card support
- Keywords management

### Sitemap (`/sitemap.xml`)
- Automatic generation
- All posts, pages, and categories
- Proper lastmod dates
- Search engine friendly

### URLs
- SEO-friendly slugs
- Automatic slug generation
- Redirect handling

## Performance Features

### Caching
- Fragment caching for lists
- Full page caching for posts
- ETags for conditional requests

### Database Optimization
- Proper indexing
- Eager loading for associations
- Scoped queries

## Accessibility

### WCAG Compliance
- Semantic HTML markup
- Proper heading hierarchy
- Alt text for images
- Keyboard navigation

### Progressive Enhancement
- Works without JavaScript
- Responsive design
- Mobile-first approach

## Customization

### Templates
- Override views in `app/views/cms/`
- Custom page templates
- Flexible layout system

### Styling
- TailwindCSS classes
- Customizable color schemes
- Typography controls

### Extensions
- Easy model extensions
- Custom content types
- Plugin architecture

## Configuration

```ruby
# config/initializers/cms.rb
Rails.application.config.cms.per_page = 10
Rails.application.config.cms.cache_expires_in = 1.hour
Rails.application.config.cms.sitemap_enabled = true
Rails.application.config.cms.default_meta_title = "Your Site"
```

## Example Usage

After installation, users can:

1. Visit `/admin/cms` to access the admin interface
2. Create categories and tags
3. Write blog posts with rich content
4. Create static pages
5. Manage SEO settings
6. View the public blog at `/blog`
7. Access individual posts at `/blog/post-title`
8. Get automatic sitemap at `/sitemap.xml`

The CMS module provides a complete content management solution with modern features like ActionText, SEO optimization, and responsive design.