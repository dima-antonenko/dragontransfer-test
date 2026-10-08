# frozen_string_literal: true

require 'simplecov'
SimpleCov.start 'rails' do
  enable_coverage :branch
  skip '/spec/'
  skip '/vendor/'
  skip '/config/'
  skip '/db/'
  skip '/app/mailers/'
  skip '/app/jobs/'
  skip '/app/helpers/'
  skip '/app/views/pwa/'
  skip '/app/views/layouts/mailer'
end

RSpec.configure do |config|
  config.expect_with :rspec do |expectations|
    expectations.include_chain_clauses_in_custom_matcher_descriptions = true
  end

  config.mock_with :rspec do |mocks|
    mocks.verify_partial_doubles = true
  end

  config.shared_context_metadata_behavior = :apply_to_host_groups
  config.filter_run_when_matching :focus
  config.example_status_persistence_file_path = 'spec/examples.txt'
  config.order = :random
  Kernel.srand config.seed
end
