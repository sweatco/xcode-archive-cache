module XcodeArchiveCache
  class Command
    class Inject < Command
      self.description = "Setup workspace or project for being built using cached dependencies"

      def self.options
        [
            ["--cachefile=/path/to/Cachefile", "Explicit Cachefile location, defaults to $PWD/Cachefile"],
            ["--destination=[<full destination specifier>|generic]", "xcodebuild-style destination. Defaults to 'generic', ignored for archive action"],
            ["--action=[build|archive]", "Action passed to xcodebuild, Defaults to 'archive'"]
        ].concat(super)
      end

      def initialize(argv)
        super
        @cachefile_path = argv.option("cachefile", "Cachefile")
        @destination = argv.option("destination", "generic")
        @action = argv.option("action", "archive")

        @destination = "generic" if @action == "archive"
      end

      def run
        config = XcodeArchiveCache::Config.from_file(@cachefile_path).current_configuration
        config.destination = @destination
        config.action = @action
        XcodeArchiveCache::Runner.new(config).run
      end
    end
  end
end
