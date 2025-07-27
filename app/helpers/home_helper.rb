# frozen_string_literal: true

module HomeHelper
  def markdown_to_html(markdown)
    return '' if markdown.blank?
    
    # Basic markdown to HTML conversion
    html = markdown.dup
    
    # Headers
    html.gsub!(/^### (.+)$/m, '<h3>\1</h3>')
    html.gsub!(/^## (.+)$/m, '<h2>\1</h2>')
    html.gsub!(/^# (.+)$/m, '<h1>\1</h1>')
    
    # Bold and italic
    html.gsub!(/\*\*(.+?)\*\*/m, '<strong>\1</strong>')
    html.gsub!(/\*(.+?)\*/m, '<em>\1</em>')
    
    # Code blocks
    html.gsub!(/```([^`]+)```/m, '<pre><code>\1</code></pre>')
    html.gsub!(/`([^`]+)`/, '<code>\1</code>')
    
    # Links
    html.gsub!(/\[([^\]]+)\]\(([^)]+)\)/, '<a href="\2">\1</a>')
    
    # Lists
    html.gsub!(/^[\*\-\+] (.+)$/m) { |match| "<li>#{$1}</li>" }
    html.gsub!(/<li>.*<\/li>/m) { |match| "<ul>#{match}</ul>" }
    
    # Numbered lists
    html.gsub!(/^\d+\. (.+)$/m) { |match| "<li>#{$1}</li>" }
    html.gsub!(/<li>.*<\/li>/m) { |match| "<ol>#{match}</ol>" if match.include?('1.') }
    
    # Paragraphs
    paragraphs = html.split(/\n\s*\n/)
    paragraphs.map! do |paragraph|
      paragraph = paragraph.strip
      next paragraph if paragraph.start_with?('<h', '<p', '<ul', '<ol', '<pre', '<div')
      next paragraph if paragraph.empty?
      
      "<p>#{paragraph}</p>"
    end
    
    paragraphs.join("\n\n").html_safe
  end

  def extract_toc_from_markdown(markdown)
    return [] if markdown.blank?
    
    headers = []
    markdown.each_line do |line|
      if line.match(/^(#+) (.+)$/)
        level = $1.length
        title = $2.strip
        anchor = title.downcase.gsub(/[^a-z0-9\-_]/, '-').gsub(/-+/, '-').gsub(/^-|-$/, '')
        
        headers << {
          level: level,
          title: title,
          anchor: anchor
        }
      end
    end
    
    headers
  end

  def navigation_items
    [
      { name: 'Home', path: '/', current: request.path == '/' },
      { name: 'Documentation', path: '/docs', current: request.path.start_with?('/docs') },
      { name: 'GitHub', path: 'https://github.com/mitchellfyi/railsplan', external: true }
    ]
  end

  def breadcrumb_items
    items = [{ name: 'Home', path: '/' }]
    
    if request.path.start_with?('/docs')
      items << { name: 'Documentation', path: '/docs' }
      
      if params[:doc_path] && params[:doc_path] != 'README'
        # Find the current doc in sections for proper naming
        @doc_sections&.each do |section|
          section[:items].each do |item|
            if item[:path] == params[:doc_path]
              items << { name: item[:name], path: request.path }
              break
            end
          end
        end
      end
    end
    
    items
  end
end