module XcodeArchiveCache
  module Injection
    class BuildFlagsChanger

      include XcodeArchiveCache::Logs

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] path
      #
      def replace_or_add_framework_search_path(build_configuration, target_name, path)
        debug("using framework search path #{path}")
        replace_or_add_flag(build_configuration, [FRAMEWORK_SEARCH_PATHS_KEY], nil, [target_name], path_to_search_path(path), true)
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
      def replace_or_add_library_search_path(build_configuration, target_name, path)
        debug("using library search path #{path}")
        replace_or_add_flag(build_configuration, [LIBRARY_SEARCH_PATHS_KEY], nil, [target_name], path_to_search_path(path), true)
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
        replace_or_add_flag(build_configuration, settings_with_modulemaps, MODULE_MAP_FLAG, old_modulemap_names, path_to_search_path(path), false)
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

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [Array<String>] setting_keys
      # @param [String] flag_name
      # @param [Array<String>] possible_old_values
      # @param [String] new_value
      #
      def replace_or_add_flag(build_configuration, setting_keys, flag_name, possible_old_values, new_value, add_if_missing)
        replaced = false

        setting_keys.each do |setting|
          replaced = replace_flag_value(build_configuration.build_settings, setting, flag_name, possible_old_values, new_value) || replaced
        end

        if build_configuration.has_xcconfig?
          replaced = replace_flag_value_in_xcconfig_recursively(
            build_configuration.get_xcconfig_path,
            build_configuration.get_project_dir,
            setting_keys,
            flag_name,
            possible_old_values,
            new_value) || replaced
        end

        if !replaced && add_if_missing
          full_value = get_full_flag_value(flag_name, new_value)

          setting_keys.each do |setting|
            add_flag_to_configuration(build_configuration, setting, full_value)
          end
        end
      end

      # @param [String] xcconfig_path
      # @param [String] project_dir
      # @param [Array<String>] setting_keys
      # @param [String] flag_name
      # @param [Array<String>] possible_old_values
      # @param [String] new_value
      #
      def replace_flag_value_in_xcconfig_recursively(xcconfig_path, project_dir, setting_keys, flag_name, possible_old_values, new_value)
        debug("changing #{possible_old_values} to #{new_value} in #{File.basename(xcconfig_path)}")
        return unless File.exist?(xcconfig_path)

        replaced = false
        xcconfig = Xcodeproj::Config.new(xcconfig_path)

        setting_keys.each do |key|
          replaced = replace_flag_value(xcconfig.attributes, key, flag_name, possible_old_values, new_value) || replaced
        end

        xcconfig.save_as(Pathname.new(xcconfig_path))

        xcconfig.includes.each do |included_xcconfig|
          included_xcconfig_path = File.join(project_dir, included_xcconfig)
          replaced = replace_flag_value_in_xcconfig_recursively(included_xcconfig_path, project_dir, setting_keys, flag_name, possible_old_values, new_value) || replaced
        end

        replaced
      end

      # @param [Hash] attributes
      # @param [String] setting_key
      # @param [String] flag_name
      # @param [Array<String>] possible_old_values
      # @param [String] new_value
      #
      def replace_flag_value(attributes, setting_key, flag_name, possible_old_values, new_value)
        build_settings = attributes[setting_key]
        return unless build_settings

        replaced = false
        is_string = build_settings.is_a?(String)
        build_settings = build_settings.split(" ") if is_string
        full_value = get_full_flag_value(flag_name, new_value)
        old_value_regexps = possible_old_values.map { |value| Regexp.new("/#{value}\"*$") }

        updated_settings = build_settings
                            .map { |line| line.split(" ") }
                            .flatten
                            .map do |line|
          if flag_name
            next line unless line.include?(flag_name)
          end

          updated_line = line

          old_value_regexps.each do |regexp|
            if regexp.match?(line)
              replaced = true
              updated_line = full_value
              break
            end
          end

          updated_line
        end

        attributes[setting_key] = is_string ? updated_settings.join(" ") : updated_settings
        replaced
      end

      def get_full_flag_value(flag_name, value)
        "#{flag_name}#{value}"
      end
    end
  end
end
