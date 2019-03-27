module XcodeArchiveCache
  class Command
    class Inject < Command
      self.description = "Setup workspace or project for being built using cached dependencies"

      def self.options
        [
            ["--cachefile=/path/to/Cachefile", "Explicit Cachefile location"]
        ].concat(super)
      end

      def initialize(argv)
        super
        @cachefile_path = argv.option("cachefile", "Cachefile")
      end

      def run
        config = XcodeArchiveCache::Config.from_file(@cachefile_path).current_configuration
        XcodeArchiveCache::Runner.new(config).run
      end
    end
  end
end