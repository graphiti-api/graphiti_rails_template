Thor::Base.shell = Thor::Shell::Color
require 'yaml'

def truthy?(statement)
  val = ask(statement)
  ['y', 'yes', ''].include?(val)
end

def eval_template(name)
  instance_eval(File.read(File.dirname(__FILE__) + "/#{name}.rb"))
end

def update_config!(attrs)
  config = File.exist?('.graphiticfg.yml') ? YAML.load_file('.graphiticfg.yml') : {}
  config.merge!(attrs)
  File.open('.graphiticfg.yml', 'w') { |f| f.write(config.to_yaml) }
end

def api_namespace
  @api_namespace ||= begin
    ns = prompt \
      header: "What is your API namespace?",
      description: "This will be used as a route prefix, e.g. if you want the route '/books_api/v1/authors' your namespace would be '/books_api/v1'",
      default: '/api/v1'
    update_config!('namespace' => ns)
    ns
  end
end

def prompt(header: nil, description: nil, default: nil)
  say(set_color("\n#{header}", :magenta, :bold)) if header
  say("\n#{description}") if description
  answer = ask(set_color("\n(default: #{default}):", :magenta, :bold))
  answer = default if answer.blank? && default != 'nil'
  say(set_color("\nGot it!\n", :white, :bold))
  answer
end

welcome = <<-STR
\n
Welcome to the Graphiti generator!
=======================================

This will take care of some boilerplate for you, like adding gem dependencies and rspec helpers.

If you're worried there might be too much magic here, feel free to run 'git diff' at the end to see what happened. You can also learn more at our documentation website, https://jsonapi-suite.github.io/jsonapi_suite
STR

say(set_color(welcome.rstrip, :cyan, :bold))
api_namespace

require 'rails/version'

gem 'graphiti'
gem 'graphiti-rails'
gem 'vandal_ui'
gem 'kaminari', '~> 1.1'

if Rails::VERSION::MAJOR == 5
  gem 'responders', '~> 2.4'
else
  gem 'responders', '~> 3.0'
end

gem_group :development, :test do
  if Rails::VERSION::MAJOR == 5
    gem 'rspec-rails', '~> 3.5.2'
  else
    gem 'rspec-rails', '~> 4.0.0beta2'
  end

  gem 'factory_bot_rails', '~> 5.0'
  gem 'faker', '~> 2.5' # keep here for seeds.rb
  gem 'graphiti_spec_helpers'
end

gem_group :test do
  gem 'database_cleaner', '~> 1.7'
end

after_bundle do
run 'bin/spring stop'

git :init
git add: '.'
run "bundle binstub rspec-core"
rails_command "generate rspec:install"
run "rm -rf test"

insert_into_file "spec/rails_helper.rb", :after => "require 'rspec/rails'\n" do
  "require 'graphiti_spec_helpers/rspec'\n"
end

insert_into_file "spec/rails_helper.rb", :after => "RSpec.configure do |config|\n" do
  <<-STR

  # bootstrap database cleaner
  config.before(:suite) do
    DatabaseCleaner.strategy = :transaction
    DatabaseCleaner.clean_with(:truncation)
  end

  config.around(:each) do |example|
    begin
      DatabaseCleaner.cleaning do
        example.run
      end
    ensure
      DatabaseCleaner.clean
    end
  end

  STR
end

insert_into_file "spec/rails_helper.rb", :after => "RSpec.configure do |config|\n" do
  <<-STR

  config.before :each do
    handle_request_exceptions(false)
  end
  STR
end

insert_into_file "spec/rails_helper.rb", :after => "RSpec.configure do |config|\n" do
  "  config.include Graphiti::Rails::TestHelpers\n"
end

insert_into_file "spec/rails_helper.rb", :after => "RSpec.configure do |config|\n" do
  "  config.include GraphitiSpecHelpers::Sugar\n"
end

insert_into_file "spec/rails_helper.rb", :after => "RSpec.configure do |config|\n" do
  "  config.include GraphitiSpecHelpers::RSpec\n"
end

insert_into_file "spec/rails_helper.rb", :after => "RSpec.configure do |config|\n" do
  "  config.include FactoryBot::Syntax::Methods\n"
end

gsub_file "spec/rails_helper.rb", 'config.fixture_path = "#{::Rails.root}/spec/fixtures"' do |match|
  "# #{match}"
end

gsub_file "spec/rails_helper.rb", 'config.use_transactional_fixtures = true' do |match|
  "# #{match}"
end

run "mkdir spec/factories"

rails_command('generate graphiti:install')
run 'bundle binstubs bundler --force'
rake('vandal:install')
say(set_color("\nYou're all set!
", :green, :bold))end
