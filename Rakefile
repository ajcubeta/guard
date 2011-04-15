require 'bundler'
Bundler::GemHelper.install_tasks

require 'rspec/core/rake_task'
RSpec::Core::RakeTask.new(:spec)
task :default => :spec

namespace(:spec) do
  desc "Run all specs on multiple ruby versions (requires rvm)"
  task(:portability) do
    %w[1.8.6 1.8.7 1.9.2 jruby rubinius].each do |version|
      system <<-BASH
        bash -c 'source ~/.rvm/scripts/rvm;
                 rvm #{version};
                 echo "--------- version #{version} ----------\n";
                 bundle install;
                 rake spec'
      BASH
    end
  end
end

require 'yard'
YARD::Rake::YardocTask.new do |t|
  t.files   = ['lib/**/*.rb']
  t.options = ['--no-private']
end
