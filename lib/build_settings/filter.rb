module XcodeArchiveCache
  module BuildSettings
    class Filter

      # @param [Hash{String => String}] settings
      #
      # @return [Hash{String => String}]
      #
      # Meaningful settings affecting build result
      # Machine-dependent settings i.e. paths, user names, group names are rejected
      #
      def filter(settings, settings_to_keep = SETTINGS_TO_KEEP)
        filtered_settings = settings.select {|name, _| settings_to_keep.include?(name)}
        SETTINGS_TO_STRIP.each do |name|
          value = filtered_settings[name]
          next if value == nil

          filtered_settings[name] = strip(value)
        end

        filtered_settings
      end

      private

      # @param [String] value
      #
      # @return [String]
      #
      def strip(value)
        # one can quote flag (like Pods do with "-D" "COCOAPODS");
        # we can safely ignore those quotes as long as
        # we won't pass our return value to any (compiler / linker) calls
        #
        # leaving quotes may lead to weird situations:
        # having value: -iquote "-D" "COCOAPODS"
        # we're going to get output: -D" "COCOAPODS"
        # because leading quote of -D becomes a part of -iquote string after split,
        # and we delete all iquotes
        #
        value_without_quotes = value.gsub(/["']/, "")

        # in case if we meet a path like "/some/dir/something -else",
        # splitting will be broken, but probability of
        # someone using such path is quite low (or it isn't ?)
        #
        value_components = value_without_quotes.split(/\s-/)

        index = 0
        indices_to_remove = []
        while index < value_components.length do
          component = value_components[index]

          PATH_FLAGS.each do |flag|
            if component.start_with?(flag)
              indices_to_remove += [index]
              break
            end
          end

          index += 1
        end

        kept_components = []
        value_components.each_with_index do |component, component_index|
          kept_components.push(component) unless indices_to_remove.include?(component_index)
        end

        kept_components.join(" -")
      end

      # TODO: extend
      SETTINGS_TO_KEEP = %w(
        ACTION 
        ALWAYS_EMBED_SWIFT_STANDARD_LIBRARIES
        APPLICATION_EXTENSION_API_ONLY
        APPLY_RULES_IN_COPY_FILES
        APS_ENV
        ARCHS
        ASSETCATALOG_COMPILER_APPICON_NAME
        ASSETCATALOG_COMPILER_LAUNCHIMAGE_NAME
        BITCODE_GENERATION_MODE
        BUILD_ACTIVE_RESOURCES_ONLY
        CLANG_ALLOW_NON_MODULAR_INCLUDES_IN_FRAMEWORK_MODULES
        CLANG_CXX_LANGUAGE_STANDARD
        CLANG_CXX_LIBRARY
        CLANG_ENABLE_MODULES
        CLANG_ENABLE_OBJC_ARC
        CLEAN_PRECOMPS
        CLONE_HEADERS
        COMBINE_HIDPI_IMAGES
        COMPRESS_PNG_FILES
        CONFIGURATION
        COPYING_PRESERVES_HFS_DATA
        COPY_HEADERS_RUN_UNIFDEF
        COPY_PHASE_STRIP
        COPY_RESOURCES_FROM_STATIC_FRAMEWORKS
        CREATE_INFOPLIST_SECTION_IN_BINARY
        DEAD_CODE_STRIPPING
        DEBUGGING_SYMBOLS
        DEBUG_INFORMATION_FORMAT
        DEFAULT_COMPILER
        DEFINES_MODULE
        DEPLOYMENT_POSTPROCESSING
        DEPLOYMENT_TARGET_CLANG_ENV_NAME
        DEPLOYMENT_TARGET_CLANG_FLAG_NAME
        DEPLOYMENT_TARGET_CLANG_FLAG_PREFIX
        DEPLOYMENT_TARGET_LD_ENV_NAME
        DEPLOYMENT_TARGET_LD_FLAG_NAME
        DEPLOYMENT_TARGET_SETTING_NAME
        EMBED_ASSET_PACKS_IN_PRODUCT_BUNDLE
        ENABLE_BITCODE
        GCC3_VERSION
        GCC_C_LANGUAGE_STANDARD
        GCC_INCREASE_PRECOMPILED_HEADER_SHARING
        GCC_INLINES_ARE_PRIVATE_EXTERN
        GCC_NO_COMMON_BLOCKS
        GCC_PREPROCESSOR_DEFINITIONS
        GCC_SYMBOLS_PRIVATE_EXTERN
        GCC_TREAT_WARNINGS_AS_ERRORS
        GCC_VERSION
        GCC_VERSION_IDENTIFIER
        GENERATE_MASTER_OBJECT_FILE
        GENERATE_PKGINFO_FILE
        GENERATE_PROFILING_CODE
        GENERATE_TEXT_BASED_STUBS
        HIDE_BITCODE_SYMBOLS
        INFOPLIST_EXPAND_BUILD_SETTINGS
        INFOPLIST_FILE
        INFOPLIST_OUTPUT_FORMAT
        INFOPLIST_PATH
        INFOPLIST_PREPROCESS
        INFOSTRINGS_PATH
        INLINE_PRIVATE_FRAMEWORKS
        IPHONEOS_DEPLOYMENT_TARGET
        JAVAC_DEFAULT_FLAGS
        JAVA_ARCHIVE_CLASSES
        JAVA_ARCHIVE_TYPE
        JAVA_FOLDER_PATH
        JAVA_FRAMEWORK_RESOURCES_DIRS
        JAVA_JAR_FLAGS
        JAVA_USE_DEPENDENCIES
        JAVA_ZIP_FLAGS
        JIKES_DEFAULT_FLAGS
        KASAN_DEFAULT_CFLAGS
        KEEP_PRIVATE_EXTERNS
        LD_GENERATE_MAP_FILE
        LD_NO_PIE
        LD_QUOTE_LINKER_ARGUMENTS_FOR_COMPILER_DRIVER
        LD_RUNPATH_SEARCH_PATHS
        LEX
        LINK_WITH_STANDARD_LIBRARIES
        LOCALIZED_RESOURCES_FOLDER_PATH
        LOCALIZED_STRING_MACRO_NAMES
        MACH_O_TYPE
        OTHERLD_FLAGS
        OTHER_CFLAGS
        OTHER_CPLUSPLUSFLAGS
        OTHER_LDFLAGS
        OTHER_SWIFT_FLAGS
        PACKAGE_TYPE
        PASCAL_STRINGS
        PBDEVELOPMENTPLIST_PATH
        PFE_FILE_C_DIALECTS
        PKGINFO_PATH
        PLATFORM_NAME
        PLIST_FILE_OUTPUT_FORMAT
        PLUGINS_FOLDER_PATH
        PRESERVE_DEAD_CODE_INITS_AND_TERMS
        PRIVATE_HEADERS_FOLDER_PATH
        PRODUCT_BUNDLE_IDENTIFIER
        PRODUCT_MODULE_NAME
        PRODUCT_NAME
        PRODUCT_TYPE
        PROFILING_CODE
        PROJECT
        PUBLIC_HEADERS_FOLDER_PATH
        RECURSIVE_SEARCH_PATHS_FOLLOW_SYMLINKS
        REMOVE_CVS_FROM_RESOURCES
        REMOVE_GIT_FROM_RESOURCES
        REMOVE_HEADERS_FROM_EMBEDDED_BUNDLES
        REMOVE_HG_FROM_RESOURCES
        REMOVE_SVN_FROM_RESOURCES
        RESOURCE_RULES_REQUIRED
        SCAN_ALL_SOURCE_FILES_FOR_INCLUDES
        SCRIPTS_FOLDER_PATH
        SDK_NAME
        SDK_NAMES
        SDK_PRODUCT_BUILD_VERSION
        SDK_VERSION
        SDK_VERSION_ACTUAL
        SDK_VERSION_MAJOR
        SDK_VERSION_MINOR
        SEPARATE_STRIP
        SEPARATE_SYMBOL_EDIT
        SHALLOW_BUNDLE
        SKIP_INSTALL
        STRINGS_FILE_OUTPUT_ENCODING
        STRIP_BITCODE_FROM_COPIED_FILES
        STRIP_INSTALLED_PRODUCT
        STRIP_STYLE
        STRIP_SWIFT_SYMBOLS
        SUPPORTED_DEVICE_FAMILIES
        SUPPORTS_TEXT_BASED_API
        SWIFT_COMPILATION_MODE
        SWIFT_OBJC_BRIDGING_HEADER
        SWIFT_PLATFORM_TARGET_PREFIX
        SWIFT_VERSION
        TAPI_VERIFY_MODE
        TARGETED_DEVICE_FAMILY
        TARGETNAME
        TARGET_NAME
        UNLOCALIZED_RESOURCES_FOLDER_PATH
        UNSTRIPPED_PRODUCT
        USE_DYNAMIC_NO_PIC
        USE_HEADERMAP
        USE_HEADER_SYMLINKS
        VALIDATE_PRODUCT
        VERBOSE_PBXCP
        VERSIONING_SYSTEM
        VERSIONPLIST_PATH
        WRAPPER_EXTENSION
        WRAPPER_NAME
        WRAPPER_SUFFIX
        WRAP_ASSET_PACKS_IN_SEPARATE_DIRECTORIES
        XCODE_PRODUCT_BUILD_VERSION
        XCODE_VERSION_ACTUAL
        XCODE_VERSION_MAJOR
        XCODE_VERSION_MINOR
        XPCSERVICES_FOLDER_PATH
        YACC
        variant
        )

      SETTINGS_TO_STRIP = %w(
        GCC_PREPROCESSOR_DEFINITIONS
        OTHERLD_FLAGS
        OTHER_CFLAGS
        OTHER_CPLUSPLUSFLAGS
        OTHER_LDFLAGS
        OTHER_SWIFT_FLAGS
      )

      # most of these are unlikely to be used,
      # most used are -I -L -F -iquote -isystem
      #
      # first part is from Clang, second is from swiftc
      # some flags mean the same for both compilers
      #
      PATH_FLAGS = %w(
        B
        cxx-isystem
        fapinotes-cache-path
        fmodules-cache-path
        fmodules-user-build-path
        fprebuilt-module-path
        fprofile-generate
        F
        iapinotes-modules
        iframeworkwithsysroot
        iprefix
        iquote
        isysroot
        isystem-after
        isystem
        iwithprefixbefore
        iwithprefix
        iwithsysroot
        I
        L
        api-diff-data-dir
        api-diff-data-file
        dump-migration-states-dir
        emit-loaded-module-trace-path
        emit-module-path
        emit-objc-header-path
        emit-parseable-module-interface-path
        emit-tbd-path
        Fsystem
        index-file-path
        index-store-path
        module-cache-path
        output-file-map
        save-optimization-record-path
        working-directory
        )
    end
  end
end
