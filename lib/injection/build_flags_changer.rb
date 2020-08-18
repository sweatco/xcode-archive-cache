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
      def add_static_lib_linker_flag(build_configuration, node)
        flag = get_linker_flag(node)
        if flag
          debug("using ld flag #{flag}")
          add_linker_flag(build_configuration, flag)
        end
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def add_static_lib_libtool_flag(build_configuration, node)
        flag = get_linker_flag(node)
        if flag
          debug("using libtool flag #{flag}")
          add_libtool_flag(build_configuration, flag)
        end
      end
      
      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] path
      #
      def add_swift_include_path(build_configuration, path)
        debug("adding #{path} to SWIFT_INCLUDE_PATHS")
        add_flag_to_configuration(build_configuration, SWIFT_INCLUDE_PATHS_KEY, path_to_search_path(path))
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] artifact_location
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

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [Array<String>] old_modulemap_names
      # @param [String] path
      #
      def fix_module_map_path(build_configuration, old_modulemap_names, path)
        debug("using #{path}")

        settings_with_modulemaps = [OTHER_CFLAGS_KEY, OTHER_CPLUSPLUSFLAGS_KEY, OTHER_SWIFT_FLAGS_KEY]
        settings_with_modulemaps.each do |setting|
          replace_path(build_configuration.build_settings, setting, MODULE_MAP_FLAG, old_modulemap_names, path)
        end

        if build_configuration.base_configuration_reference
          xcconfig_path = build_configuration.base_configuration_reference.real_path
          project_dir = File.dirname(build_configuration.project.path)

          replace_path_in_xcconfig_recursively(xcconfig_path, project_dir, settings_with_modulemaps, MODULE_MAP_FLAG, old_modulemap_names, path)
        end
      end

      private

      FRAMEWORK_SEARCH_PATHS_KEY = "FRAMEWORK_SEARCH_PATHS"
      LIBRARY_SEARCH_PATHS_KEY = "LIBRARY_SEARCH_PATHS"
      HEADER_SEARCH_PATHS_KEY = "HEADER_SEARCH_PATHS"
      OTHER_CFLAGS_KEY = "OTHER_CFLAGS"
      OTHER_CPLUSPLUSFLAGS_KEY = "OTHER_CPLUSPLUSFLAGS"
      OTHER_LDFLAGS_KEY = "OTHER_LDFLAGS"
      OTHER_LIBTOOLFLAGS_KEY = "OTHER_LIBTOOLFLAGS"
      OTHER_SWIFT_FLAGS_KEY = "OTHER_SWIFT_FLAGS"
      SWIFT_INCLUDE_PATHS_KEY = "SWIFT_INCLUDE_PATHS"
      INHERITED_SETTINGS_VALUE = "$(inherited)"

      MODULE_MAP_FLAG = "-fmodule-map-file="

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] flag
      #
      def add_linker_flag(build_configuration, flag)
        add_flag_to_configuration(build_configuration, OTHER_LDFLAGS_KEY, flag)
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] flag
      #
      def add_libtool_flag(build_configuration, flag)
        add_flag_to_configuration(build_configuration, OTHER_LIBTOOLFLAGS_KEY, flag)
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
      #         libSomething.a -> -lSomething
      #
      def get_linker_flag(node)
        return unless node.product_file_name

        node.product_file_name.gsub(/^lib/, "-l").gsub(/\.a$/, "")
      end

      # @param [String] xcconfig_path
      # @param [String] project_dir
      # @param [Array<String>] setting_keys
      # @param [String] flag_name
      # @param [Array<String>] old_paths
      # @param [String] path
      #
      def replace_path_in_xcconfig_recursively(xcconfig_path, project_dir, setting_keys, flag_name, old_paths, path)
        debug("changing #{old_paths} to #{path} in #{File.basename(xcconfig_path)}")
        return unless File.exist?(xcconfig_path)

        xcconfig = Xcodeproj::Config.new(xcconfig_path)

        setting_keys.each do |key|
          replace_path(xcconfig.attributes, key, flag_name, old_paths, path)
        end

        xcconfig.save_as(Pathname.new(xcconfig_path))

        xcconfig.includes.each do |included_xcconfig|
          included_xcconfig_path = File.join(project_dir, included_xcconfig)
          replace_path_in_xcconfig_recursively(included_xcconfig_path, project_dir, setting_keys, flag_name, old_paths, path)
        end
      end

      # @param [Hash] attributes
      # @param [String] setting_key
      # @param [String] flag_name
      # @param [Array<String>] old_paths
      # @param [String] path
      #
      def replace_path(attributes, setting_key, flag_name, old_paths, path)
        build_settings = attributes[setting_key]
        return unless build_settings

        is_string = build_settings.is_a?(String)
        build_settings = build_settings.split(" ") if is_string

        updated_settings = build_settings
                            .map { |line| line.split(" ") }
                            .flatten
                            .map do |line|
          if flag_name
            next line unless line.include?(flag_name)
          end

          updated_line = line

          old_paths.each do |old_path|
            if line.include?(old_path)
              updated_line = "#{flag_name}\"#{path}\""
              break
            end
          end

          updated_line
        end

        attributes[setting_key] = is_string ? updated_settings.join(" ") : updated_settings
      end
    end
  end
end
