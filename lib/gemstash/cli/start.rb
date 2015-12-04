require "gemstash"
require "puma/cli"

module Gemstash
  class CLI
    # This implements the command line start task to start the Gemstash server:
    #  $ gemstash start
    class Start < Gemstash::CLI::Base
      def run
        prepare
        setup_logging
        store_daemonized
        Puma::CLI.new(args, Gemstash::Logging::StreamLogger.puma_events).run
      end

    private

      def setup_logging
        return unless daemonize?
        Gemstash::Logging.setup_logger(gemstash_env.base_file("server.log"))
      end

      def store_daemonized
        Gemstash::Env.daemonized = daemonize?
      end

      def daemonize?
        @cli.options[:daemonize]
      end

      def puma_config
        File.expand_path("../../puma.rb", __FILE__)
      end

      def args
        config_args + pidfile_args + daemonize_args
      end

      def config_args
        ["--config", puma_config]
      end

      def daemonize_args
        daemonize? ? ["--daemon"] : []
      end
    end
  end
end
