require_relative "../job_worker"
require "fugit"
require "pry"

module JobWorker
  class Scheduler
    KEY = "jworkers:schedule".freeze

    def initialize(schedule)
      @schedule = schedule
      @lock = Mutex.new
      _load(schedule)
    end

    def _load(schedule)
      v = schedule.map do |key, config|
        [Fugit.parse(config["every"]).next_time.to_f, JSON.generate(config)]
      end
      connection.zadd(KEY, v)
    end

    def enqueue
      while job = connection.zrangebyscore(KEY, "-inf", Time.now.to_f, limit: [0, 1]).first
        if job
          connection.lpush("queue", JSON.generate(config))
        end
      end
    end

    def logger
      JobWorker.logger
    end

    def connection
      JobWorker.redis
    end

    def push(job)
      logger.info "Rescheduling " + job
      j = JSON.parse(job)
      n_time = Fugit.parse(j["every"]).next_time.to_f

      if j.has_key? "every"
        connection.zadd(KEY, [n_time, job])
        connection.lpush("queue", job)
      end
    end

    def run
      Thread.new do
        Thread.current["j_label"] = "Scheduler"
        logger.info "Starting Scheduler"
        @lock.synchronize do
          while true
            key = KEY
            now = Time.now.to_f
            logger.info "Re-scheduling Jobs"
            while job = connection.zrangebyscore(key, "-inf", now, limit: [0, 1]).first
              if connection.zrem(key, job)
                push(job)
              end
            end
            sleep 30
          end
        end
      end
    end
  end
end
