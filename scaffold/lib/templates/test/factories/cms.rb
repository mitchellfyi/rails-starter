# frozen_string_literal: true

# CMS Module Factories
# Factories for blog posts, categories, and content management

FactoryBot.define do
  # Post factory for blog posts
  factory :post do
    title { Faker::Lorem.sentence(word_count: 4).chomp('.') }
    slug { title.parameterize }
    excerpt { Faker::Lorem.paragraph(sentence_count: 2) }
    content { Faker::Lorem.paragraphs(number: 5).join("\n\n") }
    status { 'published' }
    published_at { rand(30.days).seconds.ago }
    author { association :user }
    workspace
    tags { [Faker::Lorem.word, Faker::Lorem.word, Faker::Lorem.word] }
    meta_title { "#{title} | Blog" }
    meta_description { excerpt.truncate(155) }
    reading_time_minutes { rand(2..15) }
    view_count { rand(0..1000) }

    trait :draft do
      status { 'draft' }
      published_at { nil }
    end

    trait :scheduled do
      status { 'scheduled' }
      published_at { rand(1..30).days.from_now }
    end

    trait :archived do
      status { 'archived' }
    end

    trait :featured do
      featured { true }
      featured_image_url { "https://images.unsplash.com/photo-#{rand(1000000000000..9999999999999)}?w=1200&h=600&fit=crop" }
    end

    trait :with_long_content do
      content { Faker::Lorem.paragraphs(number: 20).join("\n\n") }
      reading_time_minutes { rand(10..25) }
    end

    trait :popular do
      view_count { rand(1000..10000) }
      published_at { rand(7..30).days.ago }
    end

    trait :recent do
      published_at { rand(1..3).days.ago }
      view_count { rand(10..100) }
    end

    trait :technical do
      tags { ['technical', 'development', 'tutorial'] }
      title { "#{Faker::Hacker.noun.capitalize}: #{Faker::Hacker.say_something_smart}" }
      content do
        <<~CONTENT
          # #{title}

          #{Faker::Lorem.paragraph}

          ## Code Example

          ```ruby
          def example_method
            #{Faker::Hacker.say_something_smart.downcase.gsub(' ', '_')}
          end
          ```

          #{Faker::Lorem.paragraphs(number: 3).join("\n\n")}

          ## Conclusion

          #{Faker::Lorem.paragraph}
        CONTENT
      end
    end

    trait :business do
      tags { ['business', 'strategy', 'growth'] }
      title { Faker::Company.bs.split.map(&:capitalize).join(' ') }
    end

    trait :with_seo do
      meta_title { "#{title} | Complete Guide | YourSaaS" }
      meta_description { "Learn #{title.downcase} with our comprehensive guide. #{excerpt.truncate(100)}" }
      featured_image_url { "https://images.unsplash.com/photo-#{rand(1000000000000..9999999999999)}?w=1200&h=600&fit=crop" }
    end
  end

  # Category factory
  factory :category do
    name { Faker::Lorem.word.capitalize }
    slug { name.parameterize }
    description { Faker::Lorem.sentence }
    color { Faker::Color.hex_color }

    trait :technical do
      name { 'Technical' }
      slug { 'technical' }
      description { 'Deep-dive technical articles and tutorials' }
      color { '#3B82F6' }
    end

    trait :business do
      name { 'Business' }
      slug { 'business' }
      description { 'Business insights and growth strategies' }
      color { '#10B981' }
    end

    trait :tutorials do
      name { 'Tutorials' }
      slug { 'tutorials' }
      description { 'Step-by-step guides and how-to articles' }
      color { '#F59E0B' }
    end

    trait :news do
      name { 'News' }
      slug { 'news' }
      description { 'Latest updates and announcements' }
      color { '#EF4444' }
    end
  end

  # Comment factory (if comments are supported)
  factory :comment do
    post
    author { association :user }
    content { Faker::Lorem.paragraph }
    status { 'approved' }
    created_at { rand(30.days).seconds.ago }

    trait :pending do
      status { 'pending' }
    end

    trait :spam do
      status { 'spam' }
      content { "Check out this amazing #{Faker::Commerce.product_name}! Visit #{Faker::Internet.url}" }
    end

    trait :reply do
      parent { association :comment }
    end

    trait :long do
      content { Faker::Lorem.paragraphs(number: 3).join("\n\n") }
    end
  end

  # Tag factory (if tags are their own model)
  factory :tag do
    name { Faker::Lorem.word }
    slug { name.parameterize }
    color { Faker::Color.hex_color }
    posts_count { rand(1..50) }

    trait :popular do
      posts_count { rand(50..200) }
    end

    trait :technical do
      name { %w[ruby rails javascript react vue angular python django].sample }
    end

    trait :business do
      name { %w[marketing sales growth strategy pricing conversion].sample }
    end
  end

  # Newsletter factory (if newsletter functionality exists)
  factory :newsletter_subscription do
    email { Faker::Internet.unique.email }
    status { 'active' }
    subscribed_at { rand(365.days).seconds.ago }
    confirmed_at { subscribed_at + rand(1..24).hours }

    trait :unconfirmed do
      confirmed_at { nil }
    end

    trait :unsubscribed do
      status { 'unsubscribed' }
      unsubscribed_at { rand(30.days).seconds.ago }
    end

    trait :bounced do
      status { 'bounced' }
    end
  end
end