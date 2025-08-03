# frozen_string_literal: true

# Simple string extensions for RailsPlan CLI
# These provide basic Rails-like string methods when Rails is not available

class String
  def underscore
    gsub(/::/, '/')
      .gsub(/([A-Z]+)([A-Z][a-z])/, '\1_\2')
      .gsub(/([a-z\d])([A-Z])/, '\1_\2')
      .tr('-', '_')
      .downcase
  end
  
  def camelize
    split('_').map(&:capitalize).join
  end
  
  def humanize
    underscore.tr('_', ' ').split.map(&:capitalize).join(' ')
  end
  
  def pluralize
    if end_with?('y')
      self[0...-1] + 'ies'
    elsif end_with?('s', 'x', 'z', 'ch', 'sh')
      self + 'es'
    else
      self + 's'
    end
  end
end