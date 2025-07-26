# CMS/Blog Engine Module

This module adds a complete content management and blog engine to your Rails app with ActionText, WYSIWYG editing, SEO optimization, and sitemap generation.

## Features

- **Rich Content Creation**: ActionText integration with WYSIWYG editor for posts and pages
- **Image & File Support**: Upload and embed images, documents, and other attachments
- **SEO Optimization**: Meta titles, descriptions, keywords, and automatic sitemap.xml generation
- **Admin Interface**: Comprehensive admin UI for managing content, categories, and tags
- **Friendly URLs**: SEO-friendly slugged URLs for all content
- **Performance**: Built-in caching and indexing for optimal performance
- **Accessibility**: WCAG-compliant interface with proper semantic markup

## Models

- **Post**: Blog posts with rich content, categories, tags, and SEO metadata
- **Page**: Static pages (About, Terms, etc.) with rich content and SEO
- **Category**: Organize posts into hierarchical categories
- **Tag**: Tag posts for better discovery and organization

## Installation

Run the following command from your application root to install the CMS module:

```bash
bin/synth add cms
```

This will:
- Add necessary gems (image_processing, friendly_id, meta-tags)
- Generate models, controllers, and views
- Run database migrations
- Set up routes and admin interface
- Configure ActionText and file storage

## Usage

After installation:

1. **Configure storage**: Set up Active Storage for file uploads
2. **Admin access**: Visit `/admin/cms` to manage content
3. **Create content**: Use the WYSIWYG editor to create posts and pages
4. **SEO setup**: Configure meta tags and sitemap settings
5. **Customize**: Modify views and styles to match your brand

## Admin Interface

The admin interface provides:
- Posts management with draft/published states
- Pages management for static content
- Categories and tags organization
- SEO metadata editing
- Preview functionality
- Bulk operations

## Public Interface

The public interface includes:
- Blog listing with pagination
- Individual post pages
- Category and tag pages
- Static pages
- RSS feeds
- Sitemap.xml

## Configuration

Configure the CMS in `config/initializers/cms.rb`:

```ruby
Rails.application.config.cms.per_page = 10
Rails.application.config.cms.cache_expires_in = 1.hour
Rails.application.config.cms.sitemap_enabled = true
```

## Testing

Run CMS-specific tests:

```bash
bin/synth test cms
```

## Customization

The module is designed for easy customization:
- Override views in `app/views/cms/`
- Extend models with additional fields
- Customize the admin interface
- Add custom content types

## SEO Features

- Meta titles and descriptions
- Open Graph tags
- Schema.org markup
- Automatic sitemap.xml generation
- Friendly URLs with redirects
- Canonical URLs

Contributions and improvements are welcome!