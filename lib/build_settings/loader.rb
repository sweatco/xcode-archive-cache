module XcodeArchiveCache
  module BuildSettings
    class Loader

      # @param [Xcodebuild::Executor.new] executor
      #
      def initialize(executor)
        @executor = executor
        @extractor = Extractor.new
        @settings = Hash.new
      end

      # @param [String] project_path
      #
      # @return [Hash{String => String}]
      #         Target build settings keyed by target name
      #
      def load_settings(project_path)
        return if settings[project_path]

        all_targets_settings = executor.load_build_settings(project_path)
        settings[project_path] = extractor.extract_per_target(all_targets_settings)
      end

      # @param [String] project_path
      # @param [String] target_name
      #
      def get_settings(project_path, target_name)
        return nil unless settings[project_path]

        settings[project_path][target_name]
      end

      private

      # @return [XcodeArchiveCache::Xcodebuild::Executor]
      #
      attr_reader :executor

      # @return [XcodeArchiveCache::BuildSettings::Extractor]
      #
      attr_reader :extractor

      # @return [Hash{String => Hash}]
      #
      attr_reader :settings
    end
  end
end
