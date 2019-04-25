require_relative "../job_worker"

module JobWorker
  class Runner
    attr_accessor :done

    def initialize
      @done = false
      @resource = ConditionVariable.new
      @lock = Mutex.new
    end

    def enqueue
    end

    def connection
      JobWorker.redis
    end

    def logger
      JobWorker.logger
    end

    def stop
      @done = true
    end

    def start
      Thread.new do
        Thread.current["j_label"] = "Runner"
        logger.info "Starting Runner"
        @lock.synchronize do
          while true
            job = connection.brpop("queue", timeout: 2)

            if job
              @resource.wait(@lock, 2)
              logger.info "Executing " + job[1]
            else
              logger.info "Waiting for queued job"
            end
          end
        end
      end
    end
  end
end
