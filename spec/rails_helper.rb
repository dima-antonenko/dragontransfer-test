# frozen_string_literal: true

require 'spec_helper'
require 'shoulda-matchers'

ENV['RAILS_ENV'] ||= 'test'
ENV['SECRET_KEY_BASE'] ||= 'x' * 64
ENV['DRAGONTRANSFER_API_KEY'] = 'test-api-key'
ENV['DRAGONTRANSFER_BASE_URL'] = 'https://test.dragontransfer.online'
ENV['APP_HOST'] = 'http://www.example.com'
if ENV['DATABASE_URL'].to_s.include?('dragontransfer_development')
  ENV['DATABASE_URL'] = ENV['DATABASE_URL'].sub('dragontransfer_development', 'dragontransfer_test')
end

require_relative '../config/environment'
abort('The Rails environment is running in production mode!') if Rails.env.production?

require 'rspec/rails'
require 'webmock/rspec'

Rails.root.glob('spec/support/**/*.rb').sort.each { |file| require file }

begin
  ActiveRecord::Migration.maintain_test_schema!
rescue ActiveRecord::PendingMigrationError => e
  abort e.to_s.strip
end

Shoulda::Matchers.configure do |config|
  config.integrate do |with|
    with.test_framework :rspec
    with.library :rails
  end
end

RSpec.configure do |config|
  config.fixture_paths = [Rails.root.join('spec/fixtures')]
  config.use_transactional_fixtures = true
  config.infer_spec_type_from_file_location!
  config.filter_rails_from_backtrace!
  config.include FactoryBot::Syntax::Methods
  config.include PartnerApiHelpers

  config.before(:suite) do
    DragonTransfer.reset_config!
  end

  config.before do
    DragonTransfer.reset_config!
    WebMock.disable_net_connect!(allow_localhost: true)
  end
end
