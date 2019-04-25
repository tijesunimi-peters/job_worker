require "yaml"
require "redis"
require "json"

module JobWorker
  DEFAULT_OPTIONS = {}

  def self.load_yml(path)
    # binding.pry
  end

  def self.options
    DEFAULT_OPTIONS
  end

  def self.redis
    begin
      @redis ||= Redis.new
    rescue Errno::ECONNREFUSED => e
      logger.error "Connection Error"
      exit 1
    end
  end

  def self.logger
    @logger ||= Logger.new(STDOUT)
  end
end
