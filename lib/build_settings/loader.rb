module XcodeArchiveCache
  module BuildSettings
    class Loader

      # @param [Xcodebuild::Executor.new] executor
      #
      def initialize(executor)
        @executor = executor
        @extractor = Extractor.new
      end

      # @return [Hash{String => String}]
      #         Target build settings keyed by target name
      #
      def load_settings
        all_targets_settings = executor.load_build_settings
        extractor.extract_per_target(all_targets_settings)
      end

      private

      # @return [XcodeArchiveCache::Xcodebuild::Executor]
      #
      attr_reader :executor

      # @return [XcodeArchiveCache::BuildSettings::Extractor]
      #
      attr_reader :extractor
    end
  end
end
