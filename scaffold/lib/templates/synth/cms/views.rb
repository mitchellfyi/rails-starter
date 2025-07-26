# frozen_string_literal: true

# This file contains view templates for the CMS module
# These will be copied to the appropriate directories during installation

module CmsViews
  # Admin layout
  ADMIN_LAYOUT = <<~'ERB'
    <!DOCTYPE html>
    <html lang="en" class="h-full bg-gray-50">
      <head>
        <title>CMS Admin</title>
        <meta name="viewport" content="width=device-width,initial-scale=1">
        <%= csrf_meta_tags %>
        <%= csp_meta_tag %>
        
        <%= stylesheet_link_tag "tailwind", "inter-font", "data-turbo-track": "reload" %>
        <%= stylesheet_link_tag "application", "data-turbo-track": "reload" %>
        <%= javascript_importmap_tags %>
        
        <style>
          .trix-content { min-height: 300px; }
        </style>
      </head>

      <body class="h-full">
        <div class="min-h-full">
          <!-- Navigation -->
          <nav class="bg-white shadow-sm">
            <div class="mx-auto max-w-7xl px-4 sm:px-6 lg:px-8">
              <div class="flex h-16 justify-between">
                <div class="flex">
                  <div class="flex flex-shrink-0 items-center">
                    <%= link_to "CMS Admin", admin_cms_path, class: "text-xl font-bold text-gray-900" %>
                  </div>
                  <div class="hidden sm:-my-px sm:ml-6 sm:flex sm:space-x-8">
                    <%= link_to "Posts", admin_posts_path, 
                        class: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium" %>
                    <%= link_to "Pages", admin_pages_path, 
                        class: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium" %>
                    <%= link_to "Categories", admin_categories_path, 
                        class: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium" %>
                    <%= link_to "Tags", admin_tags_path, 
                        class: "border-transparent text-gray-500 hover:border-gray-300 hover:text-gray-700 inline-flex items-center px-1 pt-1 border-b-2 text-sm font-medium" %>
                  </div>
                </div>
                <div class="hidden sm:ml-6 sm:flex sm:items-center">
                  <%= link_to "View Site", root_path, 
                      class: "text-gray-500 hover:text-gray-700", target: "_blank" %>
                </div>
              </div>
            </div>
          </nav>

          <!-- Page content -->
          <div class="py-10">
            <main>
              <div class="mx-auto max-w-7xl sm:px-6 lg:px-8">
                <% if notice %>
                  <div class="rounded-md bg-green-50 p-4 mb-6">
                    <div class="flex">
                      <div class="ml-3">
                        <p class="text-sm font-medium text-green-800"><%= notice %></p>
                      </div>
                    </div>
                  </div>
                <% end %>
                
                <% if alert %>
                  <div class="rounded-md bg-red-50 p-4 mb-6">
                    <div class="flex">
                      <div class="ml-3">
                        <p class="text-sm font-medium text-red-800"><%= alert %></p>
                      </div>
                    </div>
                  </div>
                <% end %>

                <%= yield %>
              </div>
            </main>
          </div>
        </div>
      </body>
    </html>
  ERB

  # Posts index view
  POSTS_INDEX = <<~'ERB'
    <div class="sm:flex sm:items-center">
      <div class="sm:flex-auto">
        <h1 class="text-base font-semibold leading-6 text-gray-900">Posts</h1>
        <p class="mt-2 text-sm text-gray-700">Manage your blog posts and articles.</p>
      </div>
      <div class="mt-4 sm:ml-16 sm:mt-0 sm:flex-none">
        <%= link_to "New Post", new_admin_post_path, 
            class: "block rounded-md bg-indigo-600 px-3 py-2 text-center text-sm font-semibold text-white shadow-sm hover:bg-indigo-500" %>
      </div>
    </div>

    <div class="mt-8 flow-root">
      <div class="-mx-4 -my-2 overflow-x-auto sm:-mx-6 lg:-mx-8">
        <div class="inline-block min-w-full py-2 align-middle sm:px-6 lg:px-8">
          <table class="min-w-full divide-y divide-gray-300">
            <thead>
              <tr>
                <th scope="col" class="py-3.5 pl-4 pr-3 text-left text-sm font-semibold text-gray-900 sm:pl-0">Title</th>
                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Category</th>
                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Status</th>
                <th scope="col" class="px-3 py-3.5 text-left text-sm font-semibold text-gray-900">Published</th>
                <th scope="col" class="relative py-3.5 pl-3 pr-4 sm:pr-0">
                  <span class="sr-only">Actions</span>
                </th>
              </tr>
            </thead>
            <tbody class="divide-y divide-gray-200">
              <% @posts.each do |post| %>
                <tr>
                  <td class="whitespace-nowrap py-4 pl-4 pr-3 text-sm font-medium text-gray-900 sm:pl-0">
                    <%= link_to post.title, admin_post_path(post), class: "text-indigo-600 hover:text-indigo-900" %>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                    <%= post.category&.name %>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                    <% if post.published? %>
                      <span class="inline-flex items-center rounded-md bg-green-50 px-2 py-1 text-xs font-medium text-green-700 ring-1 ring-inset ring-green-600/20">Published</span>
                    <% else %>
                      <span class="inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10">Draft</span>
                    <% end %>
                  </td>
                  <td class="whitespace-nowrap px-3 py-4 text-sm text-gray-500">
                    <%= post.published_at&.strftime("%b %d, %Y") %>
                  </td>
                  <td class="relative whitespace-nowrap py-4 pl-3 pr-4 text-right text-sm font-medium sm:pr-0">
                    <%= link_to "Edit", edit_admin_post_path(post), class: "text-indigo-600 hover:text-indigo-900" %>
                    <%= link_to "Delete", admin_post_path(post), method: :delete, 
                        data: { confirm: "Are you sure?" }, 
                        class: "ml-2 text-red-600 hover:text-red-900" %>
                  </td>
                </tr>
              <% end %>
            </tbody>
          </table>
        </div>
      </div>
    </div>

    <%= paginate @posts if respond_to?(:paginate) %>
  ERB

  # Post form view
  POST_FORM = <<~'ERB'
    <%= form_with(model: [:admin, @post], local: true, class: "space-y-6") do |form| %>
      <% if @post.errors.any? %>
        <div class="rounded-md bg-red-50 p-4">
          <div class="flex">
            <div class="ml-3">
              <h3 class="text-sm font-medium text-red-800">
                <%= pluralize(@post.errors.count, "error") %> prohibited this post from being saved:
              </h3>
              <div class="mt-2 text-sm text-red-700">
                <ul role="list" class="list-disc space-y-1 pl-5">
                  <% @post.errors.full_messages.each do |message| %>
                    <li><%= message %></li>
                  <% end %>
                </ul>
              </div>
            </div>
          </div>
        </div>
      <% end %>

      <div>
        <%= form.label :title, class: "block text-sm font-medium leading-6 text-gray-900" %>
        <%= form.text_field :title, 
            class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
      </div>

      <div>
        <%= form.label :excerpt, class: "block text-sm font-medium leading-6 text-gray-900" %>
        <%= form.text_area :excerpt, rows: 3,
            class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
      </div>

      <div>
        <%= form.label :content, class: "block text-sm font-medium leading-6 text-gray-900" %>
        <%= form.rich_text_area :content, class: "mt-2" %>
      </div>

      <div class="grid grid-cols-1 gap-x-6 gap-y-6 sm:grid-cols-2">
        <div>
          <%= form.label :category_id, "Category", class: "block text-sm font-medium leading-6 text-gray-900" %>
          <%= form.collection_select :category_id, Cms::Category.published.ordered, :id, :name, 
              { prompt: "Select a category" }, 
              { class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" } %>
        </div>

        <div>
          <%= form.label :tag_ids, "Tags", class: "block text-sm font-medium leading-6 text-gray-900" %>
          <%= form.collection_check_boxes :tag_ids, Cms::Tag.ordered, :id, :name do |b| %>
            <div class="flex items-center">
              <%= b.check_box(class: "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600") %>
              <%= b.label(class: "ml-3 text-sm font-medium text-gray-700") %>
            </div>
          <% end %>
        </div>
      </div>

      <!-- SEO Fields -->
      <div class="border-t border-gray-200 pt-6">
        <h3 class="text-lg font-medium leading-6 text-gray-900">SEO Settings</h3>
        
        <div class="mt-6 space-y-6">
          <div>
            <%= form.label :meta_title, class: "block text-sm font-medium leading-6 text-gray-900" %>
            <%= form.text_field :meta_title, 
                class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
          </div>

          <div>
            <%= form.label :meta_description, class: "block text-sm font-medium leading-6 text-gray-900" %>
            <%= form.text_area :meta_description, rows: 3,
                class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
          </div>

          <div>
            <%= form.label :meta_keywords, class: "block text-sm font-medium leading-6 text-gray-900" %>
            <%= form.text_field :meta_keywords, 
                class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
            <p class="mt-2 text-sm text-gray-500">Separate keywords with commas</p>
          </div>
        </div>
      </div>

      <!-- Publishing Options -->
      <div class="border-t border-gray-200 pt-6">
        <h3 class="text-lg font-medium leading-6 text-gray-900">Publishing</h3>
        
        <div class="mt-6 space-y-6">
          <div class="flex items-center">
            <%= form.check_box :published, class: "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600" %>
            <%= form.label :published, "Published", class: "ml-3 text-sm font-medium text-gray-700" %>
          </div>

          <div class="flex items-center">
            <%= form.check_box :featured, class: "h-4 w-4 rounded border-gray-300 text-indigo-600 focus:ring-indigo-600" %>
            <%= form.label :featured, "Featured", class: "ml-3 text-sm font-medium text-gray-700" %>
          </div>

          <div>
            <%= form.label :published_at, class: "block text-sm font-medium leading-6 text-gray-900" %>
            <%= form.datetime_local_field :published_at, 
                class: "mt-2 block w-full rounded-md border-0 py-1.5 text-gray-900 shadow-sm ring-1 ring-inset ring-gray-300 placeholder:text-gray-400 focus:ring-2 focus:ring-inset focus:ring-indigo-600 sm:text-sm sm:leading-6" %>
          </div>
        </div>
      </div>

      <div class="flex items-center justify-end gap-x-6">
        <%= link_to "Cancel", admin_posts_path, 
            class: "text-sm font-semibold leading-6 text-gray-900" %>
        <%= form.submit class: "rounded-md bg-indigo-600 px-3 py-2 text-sm font-semibold text-white shadow-sm hover:bg-indigo-500 focus-visible:outline focus-visible:outline-2 focus-visible:outline-offset-2 focus-visible:outline-indigo-600" %>
      </div>
    <% end %>
  ERB

  # Sitemap XML template
  SITEMAP_XML = <<~'ERB'
    <?xml version="1.0" encoding="UTF-8"?>
    <urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9">
      <!-- Homepage -->
      <url>
        <loc><%= root_url %></loc>
        <lastmod><%= Time.current.iso8601 %></lastmod>
        <changefreq>daily</changefreq>
        <priority>1.0</priority>
      </url>
      
      <!-- Blog homepage -->
      <url>
        <loc><%= blog_url %></loc>
        <lastmod><%= @posts.maximum(:updated_at)&.iso8601 || Time.current.iso8601 %></lastmod>
        <changefreq>daily</changefreq>
        <priority>0.9</priority>
      </url>

      <!-- Blog posts -->
      <% @posts.each do |post| %>
        <url>
          <loc><%= cms_post_url(post) %></loc>
          <lastmod><%= post.updated_at.iso8601 %></lastmod>
          <changefreq>weekly</changefreq>
          <priority>0.7</priority>
        </url>
      <% end %>

      <!-- Pages -->
      <% @pages.each do |page| %>
        <url>
          <loc><%= cms_page_url(page) %></loc>
          <lastmod><%= page.updated_at.iso8601 %></lastmod>
          <changefreq>monthly</changefreq>
          <priority>0.6</priority>
        </url>
      <% end %>

      <!-- Categories -->
      <% @categories.each do |category| %>
        <url>
          <loc><%= blog_category_url(category) %></loc>
          <lastmod><%= category.updated_at.iso8601 %></lastmod>
          <changefreq>weekly</changefreq>
          <priority>0.5</priority>
        </url>
      <% end %>
    </urlset>
  ERB

  # Public blog index view
  BLOG_INDEX = <<~'ERB'
    <div class="bg-white py-24 sm:py-32">
      <div class="mx-auto max-w-7xl px-6 lg:px-8">
        <div class="mx-auto max-w-2xl lg:mx-0">
          <h2 class="text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">From the blog</h2>
          <p class="mt-2 text-lg leading-8 text-gray-600">Learn how to grow your business with our expert advice.</p>
        </div>
        
        <div class="mx-auto mt-10 grid max-w-2xl grid-cols-1 gap-x-8 gap-y-16 border-t border-gray-200 pt-10 sm:mt-16 sm:pt-16 lg:mx-0 lg:max-w-none lg:grid-cols-3">
          <% @posts.each do |post| %>
            <article class="flex max-w-xl flex-col items-start justify-between">
              <div class="flex items-center gap-x-4 text-xs">
                <time datetime="<%= post.published_at.iso8601 %>" class="text-gray-500">
                  <%= post.published_at.strftime("%b %d, %Y") %>
                </time>
                <% if post.category %>
                  <%= link_to post.category.name, blog_category_path(post.category), 
                      class: "relative z-10 rounded-full bg-gray-50 px-3 py-1.5 font-medium text-gray-600 hover:bg-gray-100" %>
                <% end %>
              </div>
              <div class="group relative">
                <h3 class="mt-3 text-lg font-semibold leading-6 text-gray-900 group-hover:text-gray-600">
                  <%= link_to cms_post_path(post) do %>
                    <span class="absolute inset-0"></span>
                    <%= post.title %>
                  <% end %>
                </h3>
                <p class="mt-5 line-clamp-3 text-sm leading-6 text-gray-600"><%= post.excerpt %></p>
              </div>
              <div class="relative mt-8 flex items-center gap-x-4">
                <div class="text-sm leading-6">
                  <p class="font-semibold text-gray-900">
                    <%= post.author.email %>
                  </p>
                </div>
              </div>
            </article>
          <% end %>
        </div>
        
        <%= paginate @posts if respond_to?(:paginate) %>
      </div>
    </div>
  ERB

  # Public blog post view
  BLOG_POST = <<~'ERB'
    <article class="mx-auto max-w-3xl px-6 py-24 lg:px-8">
      <div class="mx-auto max-w-2xl lg:mx-0">
        <time datetime="<%= @post.published_at.iso8601 %>" class="block text-sm leading-6 text-gray-600">
          <%= @post.published_at.strftime("%B %d, %Y") %>
        </time>
        <h1 class="mt-2 text-3xl font-bold tracking-tight text-gray-900 sm:text-4xl">
          <%= @post.title %>
        </h1>
        <% if @post.excerpt.present? %>
          <p class="mt-6 text-xl leading-8 text-gray-700"><%= @post.excerpt %></p>
        <% end %>
      </div>

      <div class="mx-auto mt-10 max-w-2xl lg:mx-0 lg:max-w-none">
        <div class="prose prose-lg prose-gray max-w-none">
          <%= @post.content %>
        </div>

        <div class="mt-10 border-t border-gray-200 pt-10">
          <div class="flex items-center justify-between">
            <div class="flex items-center space-x-4">
              <% if @post.category %>
                <span class="text-sm text-gray-500">Category:</span>
                <%= link_to @post.category.name, blog_category_path(@post.category), 
                    class: "text-indigo-600 hover:text-indigo-500" %>
              <% end %>
            </div>
            
            <% if @post.tags.any? %>
              <div class="flex items-center space-x-2">
                <span class="text-sm text-gray-500">Tags:</span>
                <% @post.tags.each do |tag| %>
                  <%= link_to tag.name, blog_tag_path(tag), 
                      class: "inline-flex items-center rounded-md bg-gray-50 px-2 py-1 text-xs font-medium text-gray-600 ring-1 ring-inset ring-gray-500/10" %>
                <% end %>
              </div>
            <% end %>
          </div>
        </div>
      </div>
    </article>
  ERB
end