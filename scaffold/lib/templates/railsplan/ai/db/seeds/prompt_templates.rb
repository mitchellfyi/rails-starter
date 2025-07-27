# frozen_string_literal: true

# Create example prompt templates for demonstration and testing
puts "Creating example prompt templates with versioning..."

# Basic welcome email template
welcome_template = PromptTemplate.find_or_create_by(slug: 'welcome_email') do |template|
  template.name = 'Welcome Email'
  template.description = 'Generate a personalized welcome email for new users'
  template.prompt_body = <<~PROMPT.strip
    Write a warm and professional welcome email for a new user.
    
    User Details:
    - Name: {{user_name}}
    - Email: {{user_email}}
    - Company: {{company_name}}
    - Plan: {{subscription_plan}}
    
    The email should:
    1. Welcome them personally
    2. Mention their subscription plan
    3. Provide helpful next steps
    4. Include a call-to-action to get started
    
    Keep the tone friendly but professional.
  PROMPT
  template.output_format = 'markdown'
  template.tags = ['email', 'onboarding', 'customer']
  template.active = true
  template.published = true
  template.version = '1.0.0'
end

# Create an updated version of the welcome template
if welcome_template.persisted?
  updated_welcome = welcome_template.create_new_version!(
    name: 'Welcome Email Enhanced',
    description: 'Enhanced welcome email with more personalization and features',
    prompt_body: <<~PROMPT.strip
      Create a comprehensive welcome email for a new user with enhanced personalization.
      
      User Details:
      - Name: {{user_name}}
      - Email: {{user_email}}
      - Company: {{company_name}}
      - Plan: {{subscription_plan}}
      - Industry: {{industry}}
      - Team Size: {{team_size}}
      
      The email should:
      1. Welcome them personally with their name and company
      2. Acknowledge their specific plan and industry
      3. Suggest relevant features based on team size
      4. Provide industry-specific use cases
      5. Include multiple call-to-action options
      6. Add a personal touch from the team
      
      Tone: Friendly, professional, and encouraging.
      Format: Use markdown with proper headers and sections.
    PROMPT,
    tags: ['email', 'onboarding', 'customer', 'enhanced']
  )
  
  puts "Created enhanced version of welcome email template"
end

# Product description generator
product_template = PromptTemplate.find_or_create_by(slug: 'product_description') do |template|
  template.name = 'Product Description Generator'
  template.description = 'Create compelling product descriptions for e-commerce'
  template.prompt_body = <<~PROMPT.strip
    Create a compelling product description for an e-commerce listing.
    
    Product Details:
    - Name: {{product_name}}
    - Category: {{product_category}}
    - Key Features: {{key_features}}
    - Target Audience: {{target_audience}}
    - Price Range: {{price_range}}
    
    Create a description that:
    1. Highlights the main benefits
    2. Appeals to the target audience
    3. Uses persuasive but accurate language
    4. Is optimized for search engines
    5. Includes a compelling call-to-action
    
    Format the output with clear sections for features, benefits, and specifications.
  PROMPT
  template.output_format = 'html'
  template.tags = ['ecommerce', 'marketing', 'product']
  template.active = true
  template.published = true
  template.version = '1.0.0'
end

# Meeting summary template with version evolution
meeting_template = PromptTemplate.find_or_create_by(slug: 'meeting_summary') do |template|
  template.name = 'Meeting Summary Generator'
  template.description = 'Create structured summaries from meeting transcripts'
  template.prompt_body = <<~PROMPT.strip
    Create a comprehensive meeting summary from the provided transcript.
    
    Meeting Details:
    - Date: {{meeting_date}}
    - Attendees: {{attendees}}
    - Duration: {{duration}}
    
    Transcript:
    {{transcript}}
    
    Create a summary with the following sections:
    1. **Key Decisions Made**
    2. **Action Items**
    3. **Discussion Points**
    4. **Next Steps**
    
    Be concise but comprehensive.
  PROMPT
  template.output_format = 'markdown'
  template.tags = ['productivity', 'meeting', 'summary']
  template.active = false
  template.published = false
  template.version = '1.0.0'
end

# Create improved version of meeting summary
improved_meeting = meeting_template.create_new_version!(
  name: 'Advanced Meeting Summary Generator',
  description: 'Enhanced meeting summary with action item tracking and follow-up recommendations',
  prompt_body: <<~PROMPT.strip
    Generate a comprehensive and actionable meeting summary from the provided transcript.
    
    Meeting Context:
    - Date: {{meeting_date}}
    - Meeting Type: {{meeting_type}}
    - Attendees: {{attendees}}
    - Duration: {{duration}}
    - Objective: {{meeting_objective}}
    
    Transcript:
    {{transcript}}
    
    Create a detailed summary with these sections:
    
    ## Executive Summary
    Brief 2-3 sentence overview of the meeting outcomes.
    
    ## Key Decisions Made
    List all decisions with decision makers and rationale.
    
    ## Action Items
    For each action item, include:
    - Task description
    - Assigned to
    - Due date
    - Priority level
    - Dependencies
    
    ## Discussion Highlights
    Important points discussed that didn't result in immediate actions.
    
    ## Follow-up Required
    What needs to happen before the next meeting.
    
    ## Next Meeting
    Suggested agenda items based on today's discussion.
    
    Format: Use clear markdown with tables for action items where appropriate.
  PROMPT,
  tags: ['productivity', 'meeting', 'summary', 'enhanced', 'action-tracking']
)

# Publish the improved version
improved_meeting.publish!
puts "Published improved meeting summary template"

# Data analysis insights template
data_template = PromptTemplate.find_or_create_by(slug: 'data_insights') do |template|
  template.name = 'Data Analysis Insights'
  template.description = 'Generate insights and recommendations from data analysis'
  template.prompt_body = <<~PROMPT.strip
    Analyze the provided data and generate actionable insights.
    
    Analysis Context:
    - Data Type: {{data_type}}
    - Time Period: {{time_period}}
    - Business Context: {{business_context}}
    - Key Metrics: {{key_metrics}}
    
    Data Summary:
    {{data_summary}}
    
    Provide analysis in JSON format with the following structure:
    {
      "key_findings": ["finding 1", "finding 2"],
      "trends": ["trend 1", "trend 2"],
      "recommendations": [
        {
          "action": "specific action",
          "priority": "high|medium|low",
          "impact": "expected impact",
          "timeline": "suggested timeline"
        }
      ],
      "risks": ["risk 1", "risk 2"],
      "opportunities": ["opportunity 1", "opportunity 2"]
    }
    
    Focus on actionable insights that drive business value.
  PROMPT
  template.output_format = 'json'
  template.tags = ['analytics', 'business', 'insights', 'data']
  template.active = true
  template.published = true
  template.version = '1.0.0'
end

puts "Created #{PromptTemplate.count} prompt templates"

# Create some example executions for demonstration
if PromptTemplate.exists?
  puts "Creating example prompt executions..."
  
  welcome_template = PromptTemplate.find_by(slug: 'welcome_email')
  if welcome_template
    execution = PromptExecution.find_or_create_by(
      prompt_template: welcome_template,
      input_context: {
        user_name: "John Doe",
        user_email: "john@example.com", 
        company_name: "Acme Corp",
        subscription_plan: "Pro"
      }
    ) do |exec|
      exec.rendered_prompt = welcome_template.render_with_context(exec.input_context)
      exec.status = 'completed'
      exec.output = <<~EMAIL.strip
        # Welcome to Our Platform, John!

        Hi John,

        Welcome to our platform! We're thrilled to have Acme Corp join our community of innovative companies.

        Your Pro subscription is now active and ready to use. Here's what you can do next:

        1. **Complete your profile** - Add your team members and set up your workspace
        2. **Explore features** - Check out our advanced analytics and reporting tools
        3. **Schedule a demo** - Our team can show you Pro features that will save you time

        **Ready to get started?** [Set Up Your Workspace →]

        If you have any questions, our support team is here to help at support@example.com.

        Best regards,
        The Team
      EMAIL
      exec.started_at = 1.hour.ago
      exec.completed_at = 1.hour.ago + 3.seconds
      exec.tokens_used = 245
    end
  end

  puts "Created example prompt executions"
end

puts "Seed data creation complete!"
puts ""
puts "Created templates:"
PromptTemplate.all.each do |template|
  puts "- #{template.name} (v#{template.version}) - #{template.published? ? 'Published' : 'Draft'}"
end