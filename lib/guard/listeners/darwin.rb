module Guard

  # @private
  class Darwin < Listener

    def initialize(*)
      super

    def worker
      @fsevent
    end

    def start
      super
      worker.run
    end

    def stop
      super
      worker.stop
    end

    def self.usable?
      require 'rb-fsevent'
      if !defined?(FSEvent::VERSION) || (defined?(Gem::Version) &&
          Gem::Version.new(FSEvent::VERSION) < Gem::Version.new('0.4.0'))
        UI.info "Please update rb-fsevent (>= 0.4.0)"
        false
      else
        true
      end
    end

  private

    def watch(directory)
      worker.watch(directory) do |modified_dirs|
        files = modified_files(modified_dirs)
        @callback.call(files) unless files.empty?
      end
    end

  end

end
