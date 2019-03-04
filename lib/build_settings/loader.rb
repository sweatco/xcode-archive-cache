require_relative '../xcodebuild/executor'
require_relative 'extractor'

module XcodeArchiveCache
  module BuildSettings
    class Loader

      # @param [Xcodebuild::Executor.new] executor
      #
      def initialize(executor)
        @executor = executor
        @extractor = Extractor.new
      end

      # @param [Xcodeproj::Project] project
      # @param [String] configuration
      #
      # @return [Hash{String => String}]
      #         Target build settings keyed by target name
      #
      def load_settings(project, configuration)
        all_targets_settings = executor.load_build_settings(project.path, configuration)
        @extractor.extract_per_target(all_targets_settings)
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
