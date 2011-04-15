module Guard

  # @author Thibaud Guillaume-Gentil
  # @example Real example from Guard's creator & co
  #   group 'frontend' do
  #     guard 'passenger', :ping => true do
  #       watch('config/application.rb')
  #       watch('config/environment.rb')
  #       watch(%r{^config/environments/.+\.rb})
  #       watch(%r{^config/initializers/.+\.rb})
  #     end
  #
  #     guard 'livereload', :apply_js_live => false do
  #       watch(%r{^app/.+\.(erb|haml)})
  #       watch(%r{^app/helpers/.+\.rb})
  #       watch(%r{^public/javascripts/.+\.js})
  #       watch(%r{^public/stylesheets/.+\.css})
  #       watch(%r{^public/.+\.html})
  #       watch(%r{^config/locales/.+\.yml})
  #     end
  #   end
  #
  #   group 'backend' do
  #     # Reload the bundle when the Gemfile is modified
  #     guard 'bundler' do
  #       watch('Gemfile')
  #     end
  #
  #     # for big project you can finetune the "timeout" before Spork's launch is considered failed
  #     guard 'spork', :wait => 40 do
  #       watch('Gemfile')
  #       watch('config/application.rb')
  #       watch('config/environment.rb')
  #       watch(%r{^config/environments/.+\.rb})
  #       watch(%r{^config/initializers/.+\.rb})
  #       watch('spec/spec_helper.rb')
  #     end
  #
  #     # use RSpec 2, from the system's gem and with some direct RSpec CLI options
  #     guard 'rspec', :version => 2, :cli => "--color --drb -f doc", :bundler => false do
  #       watch('spec/spec_helper.rb')                                  { "spec" }
  #       watch('app/controllers/application_controller.rb')            { "spec/controllers" }
  #       watch('config/routes.rb')                                     { "spec/routing" }
  #       watch(%r{^spec/support/(controllers|acceptance)_helpers\.rb}) { |m| "spec/#{m[1]}" }
  #       watch(%r{^spec/.+_spec\.rb})
  #
  #       watch(%r{^app/controllers/(.+)_(controller)\.rb}) { |m| ["spec/routing/#{m[1]}_routing_spec.rb", "spec/#{m[2]}s/#{m[1]}_#{m[2]}_spec.rb", "spec/acceptance/#{m[1]}_spec.rb"] }
  #
  #       watch(%r{^app/(.+)\.rb}) { |m| "spec/#{m[1]}_spec.rb" }
  #       watch(%r{^lib/(.+)\.rb}) { |m| "spec/lib/#{m[1]}_spec.rb" }
  #     end
  #   end
  class Dsl

    class << self

      # @private
      def evaluate_guardfile(options={})
        @@options = options

        if File.exists?(guardfile_path)
          begin
            new.instance_eval(File.read(guardfile_path), guardfile_path, 1)
          rescue
            UI.error "Invalid Guardfile, original error is:\n#{$!}"
            exit 1
          end
        else
          UI.error "No Guardfile in current folder, please create one."
          exit 1
        end
      end

      # @private
      def guardfile_include?(guard_name)
        File.read(guardfile_path).match(/^guard\s*\(?\s*['":]#{guard_name}['"]?/)
      end

      # @private
      def guardfile_path
        File.join(Dir.pwd, 'Guardfile')
      end
    end

    # Declare a group of guards to be run with `guard start --group group_name`
    # @param [String] name the group's name called from the CLI
    # @yield a block where you can declare several guards
    # @return [nil]
    #
    # @example With two groups named 'backend' and 'frontend' (feat. guard-spork, guard-rspec, guard-passenger and guard-livereload!)
    #   group 'backend' do
    #     guard 'spork' do ... end
    #     guard 'rspec' do ... end
    #   end
    #
    #   group 'frontend' do
    #     guard 'passenger' do ... end
    #     guard 'livereload' do ... end
    #   end
    #   # And then start Guard with something like: $ guard start --group backend
    # @see Dsl#guard
    def group(name, &guard_definition)
      guard_definition.call if guard_definition && (@@options[:group].empty? || @@options[:group].include?(name))
    end

    # Declare a guard to be used when running `guard start`
    # @param [String] name the guard's name,
    # @param [Hash] options the options accepted by the guard. Available options are different for each guard.
    # @yield a block where you can declare several watch patterns and actions
    # @note usually the name parameter is the name of the gem minus 'guard-', e.g. for 'guard-rspec', the name is 'rspec'
    # @return [nil]
    #
    # @example With the guard-rspec guard
    #   guard 'rspec' do
    #     # watch blocks declarations here
    #   end
    # @see Dsl#watch
    def guard(name, options={}, &watch_definition)
      @watchers = []
      watch_definition.call if watch_definition
      ::Guard.add_guard(name, @watchers, options)
    end

    # Define a pattern to be watched in order to run actions against on any file modification
    # @param [String, Regexp] pattern the pattern to be watched by the guard
    # @yield a block to be run when the pattern is matched
    # @yieldparam [MatchData] m matches of the pattern
    # @yieldreturn a directory, a filename, an array of directories / filenames, or nothing (can be an arbitrary command)
    # @return [nil]
    #
    # @example With the guard-rspec guard
    #   guard 'rspec' do
    #     watch('spec/spec_helper.rb')
    #     watch(%r{^.+_spec.rb})
    #     watch(%r{^app/controllers/(.+).rb}) { |m| "spec/acceptance/#{m[1]}s_spec.rb" }
    #   end
    def watch(pattern, &action)
      @watchers << ::Guard::Watcher.new(pattern, action)
    end

  end
end
