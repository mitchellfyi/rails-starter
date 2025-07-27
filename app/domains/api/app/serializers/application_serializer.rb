# frozen_string_literal: true

class ApplicationSerializer
  include JSONAPI::Serializer

  def self.inherited(subclass)
    super
    # Set common configuration for all serializers
    subclass.set_key_transform :underscore
  end
end