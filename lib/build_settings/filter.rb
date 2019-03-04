module XcodeArchiveCache
  module BuildSettings
    class Filter
      # TODO: extend
      SETTINGS_TO_KEEP = %w(ACTION ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES)

      def initialize
        @setting_name_regex = /^(?<name>[A-Z_]+)\s=/
      end

      # @param [String] settings
      #        Raw `xcodebuild -showBuildSettings` output for a single target
      #
      # @return [String]
      #         Filtered settings joined by newline
      #
      def filter(settings)
        # remove leading spaces in each line, then split to lines
        lines = settings.gsub(/\n\s{2,}/, "\n").split("\n")
        # drop "Build settings for action ..."
        lines.drop(1)

        kept_settings = lines.select do |line|
          match = @setting_name_regex.match(line)
          next unless match

          name = match["name"]
          next unless name

          SETTINGS_TO_KEEP.include?(name)
        end

        kept_settings.join("\n")
      end

      private

      # @return [Regexp]
      #
      attr_reader :setting_name_regex
    end
  end
end
