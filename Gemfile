source "https://rubygems.org"

group :test do
  gem "rake"
  gem "puppet", ENV['PUPPET_VERSION'] || '~> 6.0.2'
  gem "rspec"
  gem "rspec-puppet", '>= 2.7.1'
  gem "r10k"
  gem "puppetlabs_spec_helper"
  gem 'onceover', '>= 3.8.0'
end

group :pre do
  gem "puppet-lint"
end
