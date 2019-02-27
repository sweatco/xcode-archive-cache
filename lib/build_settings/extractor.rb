require_relative 'filter'

module XcodeArchiveCache
  module BuildSettings
    class Extractor
      def initialize
        @regex = /.+TARGETNAME\s=\s(?<target>.+)/
        @filter = Filter.new
      end

      # @param [String] build_settings
      #        Raw `xcodebuild -alltargets -showBuildSettings` output
      #
      # @return [Hash{String => String}]
      #         Target build settings keyed by target name
      #
      def extract_per_target(build_settings)
        per_target_settings = build_settings.split("Build settings for action")
        result = Hash.new

        per_target_settings.each do |target_settings|
          target_name, parsed_settings = parse(target_settings)
          next unless target_name

          result[target_name] = parsed_settings
        end

        result
      end

      private

      # @return [Regexp]
      #
      attr_reader :regex

      # @return [XcodeArchiveCache::BuildSettings::Filter]
      #
      attr_reader :filter

      # @param [String] target_settings
      #
      def parse(target_settings)
        stripped = target_settings.strip
        return nil unless stripped.length > 0

        target_name_match = @regex.match(stripped)
        return nil unless target_name_match

        target_name = target_name_match["target"]
        return nil unless target_name

        [target_name, @filter.filter(stripped)]
      end
    end
  end
end