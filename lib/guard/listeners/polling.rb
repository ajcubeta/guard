module Guard

  # @private
  class Polling < Listener

    def initialize(*)
      super

    def start
      @stop = false
      super
      watch_change
    end

    def stop
      super
      @stop = true
    end

    def on_change(&callback)
      @callback = callback
    end

  private

    def watch_change
      until @stop
        start = Time.now.to_f
        files = modified_files([@directory], :all => true)
        @callback.call(files) unless files.empty?
        nap_time = @latency - (Time.now.to_f - start)
        sleep(nap_time) if nap_time > 0
      end
    end

    def watch(directory)
      @existing = all_files
    end

  end

end
