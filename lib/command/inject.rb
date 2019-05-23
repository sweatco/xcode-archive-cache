module XcodeArchiveCache
  class Command
    class Inject < Command

      include XcodeArchiveCache::Logs

      self.description = "Setup workspace or project for being built using cached dependencies"

      def self.options
        [
            ["--cachefile=/path/to/Cachefile", "Explicit Cachefile location, defaults to $PWD/Cachefile"],
            ["--configuration", "Name of configuration from Cachefile, required"],
            ["--destination=[<full destination specifier>|generic]", "xcodebuild-style destination. Defaults to 'generic', ignored for archive action"],
            ["--storage=/path/to/storage", "Storage dir path, required"]
        ].concat(super)
      end

      DEFAULT_CACHEFILE = "Cachefile"

      def initialize(argv)
        super

        @configuration_name = argv.option("configuration")
        if @configuration_name == nil
          error("configuration is required")
          exit 1
        end

        @storage = argv.option("storage")
        if @storage == nil
          error("storage parameter is required")
          exit 1
        end

        @cachefile_path = argv.option("cachefile", DEFAULT_CACHEFILE)
        @destination = argv.option("destination", XcodeArchiveCache::Xcodebuild::GENERIC_DESTINATION)
      end

      def run
        config = XcodeArchiveCache::Config.from_file(@cachefile_path).entry
        config.settings.destination = @destination
        config.active_configuration_name = @configuration_name
        config.storage.type = :local
        config.storage.path = @storage

        debug(config)

        XcodeArchiveCache::Runner.new(config).run
      end
    end
  end
end
