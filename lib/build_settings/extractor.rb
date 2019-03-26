module XcodeArchiveCache
  module BuildSettings
    class Extractor

      def initialize
        @parser = Parser.new
        @filter = Filter.new
      end

      # @param [String] build_settings
      #        Raw `xcodebuild -alltargets -showBuildSettings` output
      #
      # @return [Hash{String => Container}]
      #         Target build settings keyed by target name
      #
      def extract_per_target(build_settings)
        per_target_settings = build_settings.split("Build settings for action")
        result = Hash.new

        per_target_settings.each do |target_settings|
          parsed_settings = parse(target_settings)
          target_name = get_target_name(parsed_settings)
          next unless target_name

          filtered_settings = filter.filter(parsed_settings)
          result[target_name] = Container.new(parsed_settings, filtered_settings)
        end

        result
      end

      private

      # @return [Filter]
      #
      attr_reader :filter

      # @return [Parser]
      #
      attr_reader :parser

      # @param [String] settings
      #
      # @return [Hash{String => String}]
      #         Setting values keyed by setting names
      #
      def parse(settings)
        # remove leading spaces in each line, then split to lines
        lines = settings.strip.gsub(/\n\s{2,}/, "\n").split("\n")
        # drop "Build settings for action ..."
        lines.drop(1)

        result = Hash.new

        lines.each do |line|
          name = parser.parse_name(line)
          next unless name

          value = parser.parse_value(line)
          next unless value

          result[name] = value
        end

        result
      end

      TARGET_NAME_KEY = "TARGETNAME".freeze

      # @param [Hash{String => String}] parsed_settings
      #
      # @return [String]
      #         Name of target that settings apply to
      #
      def get_target_name(parsed_settings)
        parsed_settings[TARGET_NAME_KEY]
      end
    end
  end
end
