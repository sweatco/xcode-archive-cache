module XcodeArchiveCache
  module BuildSettings
    class Filter

      # TODO: extend
      SETTINGS_TO_KEEP = %w(ACTION ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES)

      # @param [Hash{String => String}] settings
      #
      # @return [Hash{String => String}]
      #
      # Meaningful settings affecting build result
      # Machine-dependent settings i.e. paths are rejected
      #
      def filter(settings)
        settings.select do |name, value|
          SETTINGS_TO_KEEP.include?(name)
        end
      end
    end
  end
end
