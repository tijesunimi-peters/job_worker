# $stdout.sync = true

require "singleton"
require "optparse"
require "logger"
require "fileutils"
require "erb"
require "pry"

require_relative "../job_worker"
require_relative "./version"
require_relative "./scheduler"
require_relative "./runner"

module JobWorker
  class CLI
    include Singleton

    SIGNAL_HANDLERS = {
      # Ctrl-C in terminal
      "INT" => -> (cli) {
        JobWorker.logger.info "Interupted"
        raise Interrupt
      },
      # TERM is the signal that Sidekiq must exit.
      # Heroku sends TERM and then waits 30 seconds for process to exit.
      "TERM" => -> (cli) { raise Interrupt },
      "USR1" => -> (cli) {
        JobWorker.logger.info "Received USR1, no longer accepting new work"
        # cli.launcher.quiet
      },
      "TSTP" => -> (cli) {
        JobWorker.logger.info "Received TSTP, no longer accepting new work"
        #   cli.launcher.quiet
      },
      "USR2" => -> (cli) {
        #   if Sidekiq.options[:logfile]
        #     Sidekiq::Logging.reopen_logs
        # end
        JobWorker.logger.info "Received USR2, reopening log file"
      },
      "TTIN" => -> (cli) {
        Thread.list.each do |thread|
          JobWorker.logger.warn "Thread TID-#{(thread.object_id ^ ::Process.pid).to_s(36)} #{thread["j_label"]}"
          if thread.backtrace
            JobWorker.logger.warn thread.backtrace.join("\n")
          else
            JobWorker.logger.warn "<no backtrace available>"
          end
        end
      },
    }

    def handle_signal(sig)
      @logger.debug "Got #{sig} signal"
      handy = SIGNAL_HANDLERS[sig]
      if handy
        handy.call(self)
      else
        @logger.info { "No signal handler for #{sig}" }
      end
    end

    def parse(args = ARGV)
      flush_db
      setup_logger
      parse_options(args)
    end

    def flush_db
      JobWorker.redis.flushdb
    end

    def jruby?
      defined?(::JRUBY_VERSION)
    end

    def run
      self_read, self_write = IO.pipe
      sigs = %w(INT TERM TTIN TSTP)
      # USR1 and USR2 don't work on the JVM
      # if !jruby?
      #   sigs << "USR1"
      #   sigs << "USR2"
      # end

      sigs.each do |sig|
        begin
          trap sig do
            self_write.write("#{sig}\n")
          end
        rescue ArgumentError
          puts "Signal #{sig} not supported"
        end
      end

      @schedule = load_schedule
      @runner = Runner.new

      begin
        @schedule.run
        @runner.start

        while r_io = IO.select([self_read])
          signal = r_io.first[0].gets.strip
          handle_signal signal
        end
      rescue Interrupt
        @runner.stop
      end
    end

    def load_schedule
      unless options[:schedule_file]
        @logger.error "You need to provide a scheduler file"
        exit(1)
      end

      unless /\.ya?ml/ =~ File.extname(options[:schedule_file])
        @logger.error "You need to provide a a yaml file"
        exit(1)
      end

      unless File.exist?(options[:schedule_file])
        @logger.error "Config file does not exist"
        exit 1
      end

      file_path = File.expand_path(options[:schedule_file])

      begin
        schedule = YAML.load(ERB.new(File.read(file_path)).result) || {}
        Scheduler.new(schedule)
      rescue => e
        @logger.error e.message
        @logger.error e.backtrace.join("\n")
        exit 1
      end
    end

    def parse_options(argv)
      opts = {}

      @parser = OptionParser.new do |o|
        o.on "-S", "--schedule PATH", "path to YAML schedule file" do |arg|
          opts[:schedule_file] = arg
        end

        o.on "-V", "--version", "print version and exit" do |arg|
          puts "JobWorker #{JobWorker::VERSION}"
          exit(0)
        end
      end

      @parser.banner = "job_worker [options]"
      @parser.on_tail "-h", "--help", "Show help" do
        @logger.info @parser
        exit(0)
      end

      @parser.parse!(argv)

      options.merge!(opts)
    end

    def setup_logger
      @logger = JobWorker.logger
    end

    def options
      JobWorker.options
    end
  end
end
