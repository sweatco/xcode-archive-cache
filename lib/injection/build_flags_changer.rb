module XcodeArchiveCache
  module Injection
    class BuildFlagsChanger

      include XcodeArchiveCache::Logs

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] path
      #
      def add_framework_search_path(build_configuration, path)
        debug("using framework search path #{path}")
        add_flag_to_configuration(build_configuration, FRAMEWORK_SEARCH_PATHS_KEY, path_to_search_path(path))
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def add_framework_linker_flag(build_configuration, node)
        linker_flag = get_framework_linker_flag(node)
        if linker_flag
          debug("using linker flag #{linker_flag}")
          add_linker_flag(build_configuration, linker_flag)
        end
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def add_framework_headers_iquote(build_configuration, artifact_location, node)
        headers_search_path = get_framework_headers_iquote(artifact_location, node)
        debug("using -iquote path #{headers_search_path}")
        add_cflag(build_configuration, headers_search_path)
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] path
      #
      def add_library_search_path(build_configuration, path)
        debug("using library search path #{path}")
        add_flag_to_configuration(build_configuration, LIBRARY_SEARCH_PATHS_KEY, path_to_search_path(path))
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] path
      #
      def add_headers_search_path(build_configuration, path)
        debug("using headers search path #{path}")
        add_flag_to_configuration(build_configuration, HEADER_SEARCH_PATHS_KEY, path)
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] path
      #
      def add_iquote_path(build_configuration, path)
        debug("using -iquote path #{path}")
        add_cflag(build_configuration, path_to_iquote(path))
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] path
      #
      def add_capital_i_path(build_configuration, path)
        debug("using -I path #{path}")
        add_cflag(build_configuration, path_to_capital_i(path))
      end

      private

      FRAMEWORK_SEARCH_PATHS_KEY = "FRAMEWORK_SEARCH_PATHS"
      LIBRARY_SEARCH_PATHS_KEY = "LIBRARY_SEARCH_PATHS"
      HEADER_SEARCH_PATHS_KEY = "HEADER_SEARCH_PATHS"
      OTHER_CFLAGS_KEY = "OTHER_CFLAGS"
      OTHER_LDFLAGS_KEY = "OTHER_LDFLAGS"
      INHERITED_SETTINGS_VALUE = "$(inherited)"

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] flag
      #
      def add_linker_flag(build_configuration, flag)
        add_flag_to_configuration(build_configuration, OTHER_LDFLAGS_KEY, flag)
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] flag
      #
      def add_cflag(build_configuration, flag)
        add_flag_to_configuration(build_configuration, OTHER_CFLAGS_KEY, flag)
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] key
      # @param [String] flag
      #
      def add_flag_to_configuration(build_configuration, key, flag)
        flags = build_configuration.build_settings[key]
        build_configuration.build_settings[key] = add_flag(flags, flag)
      end

      # @param [Object] flags
      # @param [String] new_flag
      #
      # @return [Array<String>]
      #
      def add_flag(flags, new_flag)
        if flags && flags.length > 0
          if flags.is_a?(String)
            flags = [flags, new_flag]
          elsif flags.is_a?(Array)
            flags += [new_flag] unless flags.include?(new_flag)
          else
            raise StandardError.new, "Flags value is neither string nor array: #{flags.class}"
          end
        else
          flags = [INHERITED_SETTINGS_VALUE, new_flag]
        end

        flags
      end

      # @param [String] path
      #
      # @return [String]
      #
      def path_to_search_path(path)
        "\"#{path}\""
      end

      # @param [String] path
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [String]
      #
      def get_framework_headers_iquote(path, node)
        if node.has_framework_product?
          headers_dir_path = File.join(path, node.product_file_name, "Headers")
          path_to_iquote(headers_dir_path)
        end
      end

      # @param [String] path
      #
      # @return [String]
      #
      def path_to_iquote(path)
        "-iquote \"#{path}\""
      end

      # @param [String] path
      #
      # @return [Stirng]
      #
      def path_to_capital_i(path)
        "-I\"#{path}\""
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [String]
      #
      #         Something.framework -> -framework "Something"
      #
      def get_framework_linker_flag(node)
        return unless node.product_file_name

        framework_name = File.basename(node.product_file_name, File.extname(node.product_file_name))
        return unless framework_name

        "-framework \"#{framework_name}\""
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [String]
      #
      #         libSomething.a -> -l"Something"
      #
      def get_static_lib_linker_flag(node)
        return unless node.product_file_name

        library_name = File.basename(node.product_file_name, File.extname(node.product_file_name)).gsub("lib", "")
        return unless library_name

        "-l\"#{library_name}\""
      end
    end
  end
end
