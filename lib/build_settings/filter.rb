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
      SETTINGS_TO_KEEP = %w(
        ACTION 
        ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES 
        ARCH BITCODE_GENERATION_MODE 
        BUILD_COMPONENTS
        CLANG_CXX_LANGUAGE_STANDARD
        CLANG_CXX_LIBRARY
        CLANG_ENABLE_MODULES
        CLANG_ENABLE_OBJC_ARC
        COMBINE_HIDPI_IMAGES
        COMPRESS_PNG_FILES
        COPY_RESOURCES_FROM_STATIC_FRAMEWORKS
        CREATE_INFOPLIST_SECTION_IN_BINARY
        DEBUG_INFORMATION_FORMAT
        DEFINES_MODULE
        EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE
        ENABLE_BITCODE
        TARGETNAME
        )
    end
  end
end
