module Guard

  # @private
  class Guard
    attr_accessor :watchers, :options

    def initialize(watchers=[], options={})
      @watchers, @options = watchers, options
    end

    # Guardfile template needed inside guard gem
    def self.init(name)
      if ::Guard::Dsl.guardfile_include?(name)
        ::Guard::UI.info "Guardfile already include #{name} guard"
      else
        content = File.read('Guardfile')
        guard   = File.read("#{::Guard.locate_guard(name)}/lib/guard/#{name}/templates/Guardfile")
        File.open('Guardfile', 'wb') do |f|
          f.puts(content)
          f.puts("")
          f.puts(guard)
        end
        ::Guard::UI.info "#{name} guard added to Guardfile, feel free to edit it"
      end
    end

    # =================
    # = Guard methods =
    # =================

    # If one of those methods raise an exception, the Guard::GuardName instance
    # will be removed from the active guards.

    # Called once when Guard starts
    # Please override initialize method to init stuff
    def start
      true
    end

    # Called on Ctrl-C signal (when Guard quits)
    def stop
      true
    end

    # Called on Ctrl-Z signal
    # This method should be mainly used for "reload" (really!) actions like reloading passenger/spork/bundler/...
    def reload
      true
    end

    # Called on Ctrl-/ signal
    # This method should be principally used for long action like running all specs/tests/...
    def run_all
      true
    end

    # Called on file(s) modifications
    def run_on_change(paths)
      true
    end

  end
end
