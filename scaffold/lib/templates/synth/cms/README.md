# CMS Module

Content management system with blog engine, SEO optimization, and newsletter capabilities.

## Features

- **Blog Posts**: Rich content with markdown support, SEO metadata, and scheduling
- **Categories & Tags**: Organize content with hierarchical categories and flexible tagging
- **Comments**: User engagement with moderation and threading support
- **Newsletter**: Email subscription management with status tracking
- **SEO Optimization**: Meta titles, descriptions, featured images, and reading time estimates

## Models

- `Post`: Blog posts with content, metadata, and publishing workflow
- `Category`: Content categorization with descriptions and colors
- `Comment`: User comments with moderation and reply threading
- `Tag`: Flexible tagging system with usage tracking
- `NewsletterSubscription`: Email subscription management

## Seed Data

The CMS seeds create:

- **Welcome Post**: Introduction to the Rails SaaS starter template
- **Technical Post**: Deep-dive on AI prompt templates and workflows  
- **Business Post**: Pricing strategies and lessons learned from real deployments
- **Draft Post**: Example of content in draft status for testing
- **Categories**: Technical, Business, Tutorials, and News categories
- **Sample Metadata**: SEO titles, descriptions, featured images, and reading times

## Installation

```sh
bin/synth add cms
```

## Features Included

- SEO-friendly URLs with FriendlyId
- Image processing for featured images
- Comment moderation system
- Newsletter subscription management
- Reading time estimation
- View count tracking

## Usage

```ruby
# Create a blog post
post = Post.create!(
  title: 'Getting Started with AI',
  content: 'Learn how to build AI-powered features...',
  status: 'published',
  author: current_user,
  workspace: current_workspace,
  tags: ['ai', 'tutorial'],
  meta_title: 'AI Tutorial | Your SaaS',
  meta_description: 'Complete guide to AI integration'
)

# Add to category
post.update!(category: Category.find_by(slug: 'technical'))

# Track views
post.increment!(:view_count)
```

## SEO Features

All posts include:
- Meta titles and descriptions optimized for search engines
- Featured images with proper dimensions (1200x600)
- Reading time estimates
- Clean, SEO-friendly URLs
- Structured data markup (can be added to views)