module XcodeArchiveCache
  class Command < CLAide::Command

    include XcodeArchiveCache::Logs

    self.abstract_command = true
    self.command = "cache"
    self.description = "XcodeArchiveCache, cache for Xcode archive action"

    def self.options
      [
          ["--log-level=[nothing|info|verbose]", "Level of log verbosity, defaults to info"]
      ].concat(super.reject { |(name, _)| name != '--help' })
    end

    def self.run(argv)
      help! "You cannot run XcodeArchiveCache as root." if Process.uid == 0 && !Gem.win_platform?

      super(argv)
    end

    def initialize(argv)
      super
      log_level = argv.option("log-level", "info")
      set_log_level(log_level)
    end
  end

  def self.report_error(exception)
    case exception
    when Interrupt
      info("Cancelled")
      exit 1
    when SystemExit
      raise
    else
      if ENV["XCODE_ARCHIVE_CACHE_ENV"] != "development"
        error(exception.message)
        exit 1
      else
        raise exception
      end
    end
  end
end
