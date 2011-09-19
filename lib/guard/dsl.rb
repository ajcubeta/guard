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
      @@options = nil

      def evaluate_guardfile(options = {})
        options.is_a?(Hash) or raise ArgumentError.new("evaluate_guardfile not passed a Hash!")

        @@options = options.dup
        fetch_guardfile_contents
        instance_eval_guardfile(guardfile_contents_with_user_config)

        UI.error "No guards found in Guardfile, please add at least one." if !::Guard.guards.nil? && ::Guard.guards.empty?
      end

      def reevaluate_guardfile
        ::Guard.guards.clear
        @@options.delete(:guardfile_contents)
        Dsl.evaluate_guardfile(@@options)
        msg = "Guardfile has been re-evaluated."
        UI.info(msg)
        Notifier.notify(msg)
      end

      def instance_eval_guardfile(contents)
        begin
          new.instance_eval(contents, @@options[:guardfile_path], 1)
        rescue
          UI.error "Invalid Guardfile, original error is:\n#{$!}"
          exit 1
        end
      end

      def guardfile_include?(guard_name)
        guardfile_contents.match(/^guard\s*\(?\s*['":]#{guard_name}['"]?/)
      end

      def read_guardfile(guardfile_path)
        begin
          @@options[:guardfile_path]     = guardfile_path
          @@options[:guardfile_contents] = File.read(guardfile_path)
        rescue
          UI.error("Error reading file #{guardfile_path}")
          exit 1
        end
      end

      def fetch_guardfile_contents
        # TODO: do we need .rc file interaction?
        if @@options[:guardfile_contents]
          UI.info "Using inline Guardfile."
          @@options[:guardfile_path] = 'Inline Guardfile'

        elsif @@options[:guardfile]
          if File.exist?(@@options[:guardfile])
            read_guardfile(@@options[:guardfile])
            UI.info "Using Guardfile at #{@@options[:guardfile]}."
          else
            UI.error "No Guardfile exists at #{@@options[:guardfile]}."
            exit 1
          end

        else
          if File.exist?(guardfile_default_path)
            read_guardfile(guardfile_default_path)
          else
            UI.error "No Guardfile found, please create one with `guard init`."
            exit 1
          end
        end

        unless guardfile_contents_usable?
          UI.error "The command file(#{@@options[:guardfile]}) seems to be empty."
          exit 1
        end
      end

      def guardfile_contents
        @@options ? @@options[:guardfile_contents] : ""
      end

      def guardfile_contents_with_user_config
        config = File.read(user_config_path) if File.exist?(user_config_path)
        [guardfile_contents, config].join("\n")
      end

      def guardfile_path
        @@options ? @@options[:guardfile_path] : ""
      end

      def guardfile_contents_usable?
        guardfile_contents && guardfile_contents.size >= 'guard :a'.size # smallest guard-definition
      end

      def guardfile_default_path
        File.exist?(local_guardfile_path) ? local_guardfile_path : home_guardfile_path
      end

    private

      def local_guardfile_path
        File.join(Dir.pwd, "Guardfile")
      end

      def home_guardfile_path
        File.expand_path(File.join("~", ".Guardfile"))
      end

      def user_config_path
        File.expand_path(File.join("~", ".guard.rb"))
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
      @groups = @@options[:group] || []
      name = name.to_sym

      if guard_definition && (@groups.empty? || @groups.map(&:to_sym).include?(name))
        @current_group = name
        guard_definition.call
        @current_group = nil
      end
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
    def guard(name, options = {}, &watch_and_callback_definition)
      @watchers  = []
      @callbacks = []
      watch_and_callback_definition.call if watch_and_callback_definition
      options.update(:group => (@current_group || :default))
      ::Guard.add_guard(name.to_s.downcase.to_sym, @watchers, @callbacks, options)
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

    def callback(*args, &listener)
      listener, events = args.size > 1 ? args : [listener, args[0]]
      @callbacks << { :events => events, :listener => listener }
    end

    def ignore_paths(*paths)
      UI.info "Ignoring paths: #{paths.join(', ')}"
      ::Guard.listener.ignore_paths.push(*paths)
    end
  end
end
