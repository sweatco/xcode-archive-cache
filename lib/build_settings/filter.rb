module XcodeArchiveCache
  module BuildSettings
    class Filter

      # @param [Hash{String => String}] settings
      #
      # @return [Hash{String => String}]
      #
      # Meaningful settings affecting build result
      # Machine-dependent settings i.e. paths are rejected
      #
      def filter(settings, settings_to_keep = SETTINGS_TO_KEEP)
        settings.select do |name, _|
          settings_to_keep.include?(name)
        end
      end

      private

      # TODO: extend
      SETTINGS_TO_KEEP = %w(ACTION ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES)
    end
  end
end
