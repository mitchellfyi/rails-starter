# frozen_string_literal: true

module JsonApiHelpers
  def json_response
    JSON.parse(response.body)
  end

  def json_data
    json_response['data']
  end

  def json_errors
    json_response['errors']
  end

  def json_api_headers
    {
      'Content-Type' => 'application/vnd.api+json',
      'Accept' => 'application/vnd.api+json'
    }
  end

  def expect_json_api_error(status:, detail: nil)
    expect(response).to have_http_status(status)
    expect(json_errors).to be_present
    expect(json_errors.first['detail']).to include(detail) if detail
  end

  def expect_json_api_resource(type:, attributes: {})
    expect(json_data['type']).to eq(type)
    attributes.each do |key, value|
      expect(json_data['attributes'][key.to_s]).to eq(value)
    end
  end
end

RSpec.configure do |config|
  config.include JsonApiHelpers, type: :request
end