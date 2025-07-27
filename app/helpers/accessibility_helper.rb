module AccessibilityHelper
  # Generates a skip link for keyboard navigation
  def skip_link(target_id, text = "Skip to main content", options = {})
    default_classes = "sr-only focus:not-sr-only focus:absolute focus:top-2 focus:left-2 focus:z-50 focus:bg-indigo-600 focus:text-white focus:px-4 focus:py-2 focus:rounded-md focus:no-underline"
    classes = options[:class] ? "#{default_classes} #{options[:class]}" : default_classes
    
    link_to text, "##{target_id}", class: classes, **options.except(:class)
  end

  # Generates an accessible icon with proper ARIA attributes
  def accessible_icon(svg_content, options = {})
    title = options[:title]
    role = options[:role] || (title ? "img" : nil)
    aria_hidden = title ? nil : "true"
    
    content_tag :svg, svg_content, 
                class: options[:class],
                role: role,
                "aria-hidden": aria_hidden,
                "aria-label": title,
                viewBox: options[:viewBox] || "0 0 24 24",
                fill: options[:fill] || "currentColor"
  end

  # Generates proper heading with automatic level management
  def accessible_heading(text, options = {})
    level = options[:level] || infer_heading_level
    tag_name = "h#{level}"
    id = options[:id] || text.parameterize
    
    content_tag tag_name, text, 
                id: id,
                class: options[:class],
                **options.except(:level, :class, :id)
  end

  # Creates an accessible button with proper ARIA attributes
  def accessible_button(text, options = {})
    button_options = {
      type: options[:type] || "button",
      class: options[:class],
      "aria-label": options[:aria_label] || text,
      "aria-expanded": options[:aria_expanded],
      "aria-haspopup": options[:aria_haspopup],
      "aria-controls": options[:aria_controls],
      disabled: options[:disabled]
    }.compact

    button_tag(**button_options) do
      if options[:icon]
        concat accessible_icon(options[:icon], title: options[:icon_title])
        concat content_tag(:span, text, class: options[:text_class])
      else
        text
      end
    end
  end

  # Creates an accessible form field with proper labeling
  def accessible_form_field(form, field_name, options = {})
    field_type = options[:type] || :text_field
    label_text = options[:label] || field_name.to_s.humanize
    help_text = options[:help]
    required = options[:required]
    
    field_id = "#{form.object_name}_#{field_name}"
    help_id = help_text ? "#{field_id}_help" : nil
    
    content_tag :div, class: "form-field" do
      concat form.label(field_name, label_text, class: "form-label #{'required' if required}")
      
      field_options = {
        id: field_id,
        class: options[:field_class] || "form-input",
        "aria-describedby": help_id,
        "aria-required": required
      }.compact

      concat form.send(field_type, field_name, **field_options.merge(options[:field_options] || {}))
      
      if help_text
        concat content_tag(:p, help_text, id: help_id, class: "form-help")
      end
    end
  end

  # Creates an accessible navigation menu
  def accessible_nav(items, options = {})
    nav_label = options[:label] || "Navigation"
    current_path = options[:current_path] || request.path
    
    content_tag :nav, "aria-label": nav_label, class: options[:class] do
      content_tag :ul, role: "list" do
        items.map do |item|
          is_current = current_path == item[:path]
          link_options = {
            class: "#{item[:class]} #{'current' if is_current}".strip,
            "aria-current": (is_current ? "page" : nil)
          }.compact

          content_tag :li do
            link_to item[:text], item[:path], **link_options
          end
        end.join.html_safe
      end
    end
  end

  # Generates an accessible modal/dialog
  def accessible_modal(id, title, options = {})
    content_tag :div, 
                id: id,
                class: "modal #{options[:class]}".strip,
                role: "dialog",
                "aria-modal": "true",
                "aria-labelledby": "#{id}_title",
                "aria-describedby": options[:description_id] do
      
      content_tag :div, class: "modal-content" do
        concat content_tag(:h2, title, id: "#{id}_title", class: "modal-title")
        concat content_tag(:div, yield, class: "modal-body")
        
        if options[:show_close]
          concat accessible_button("Close", 
                                   class: "modal-close",
                                   aria_label: "Close #{title} dialog",
                                   data: { action: "click->modal#close" })
        end
      end
    end
  end

  # Generates accessible breadcrumbs
  def accessible_breadcrumbs(items, options = {})
    return if items.blank?
    
    content_tag :nav, "aria-label": "Breadcrumb", class: options[:class] do
      content_tag :ol, class: "breadcrumb-list" do
        items.each_with_index.map do |item, index|
          is_last = index == items.length - 1
          
          content_tag :li, class: "breadcrumb-item" do
            if is_last
              content_tag :span, item[:text], "aria-current": "page"
            else
              link_to item[:text], item[:path]
            end
          end
        end.join.html_safe
      end
    end
  end

  # Generates an accessible live region for dynamic updates
  def accessible_live_region(id, options = {})
    politeness = options[:politeness] || "polite" # or "assertive"
    
    content_tag :div,
                id: id,
                "aria-live": politeness,
                "aria-atomic": options[:atomic] || "true",
                class: "sr-only #{options[:class]}".strip do
      yield if block_given?
    end
  end

  private

  def infer_heading_level
    # This is a simple implementation - in a real app you might want more sophisticated logic
    # to track heading levels throughout the page rendering
    controller_name = controller.controller_name
    action_name = controller.action_name
    
    case action_name
    when 'index'
      1
    when 'show'
      2
    else
      2
    end
  end
end