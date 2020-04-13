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

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] path
      #
      def fix_module_map_path(build_configuration, old_modulemap_names, path)
        replace_module_map_flag(build_configuration.build_settings, OTHER_CFLAGS_KEY, old_modulemap_names, path)
        replace_module_map_flag(build_configuration.build_settings, OTHER_CPLUSPLUSFLAGS_KEY, old_modulemap_names, path)
        replace_module_map_flag(build_configuration.build_settings, OTHER_SWIFT_FLAGS_KEY, old_modulemap_names, path)

        if build_configuration.base_configuration_reference
          xcconfig_path = build_configuration.base_configuration_reference.real_path
          return unless File.exist?(xcconfig_path)
          xcconfig = Xcodeproj::Config.new(xcconfig_path)

          replace_module_map_flag(xcconfig.attributes, OTHER_CFLAGS_KEY, old_modulemap_names, path)
          replace_module_map_flag(xcconfig.attributes, OTHER_CPLUSPLUSFLAGS_KEY, old_modulemap_names, path)
          replace_module_map_flag(xcconfig.attributes, OTHER_SWIFT_FLAGS_KEY, old_modulemap_names, path)

          xcconfig.save_as(Pathname.new(xcconfig_path))
        end
      end

      private

      FRAMEWORK_SEARCH_PATHS_KEY = "FRAMEWORK_SEARCH_PATHS"
      LIBRARY_SEARCH_PATHS_KEY = "LIBRARY_SEARCH_PATHS"
      HEADER_SEARCH_PATHS_KEY = "HEADER_SEARCH_PATHS"
      OTHER_CFLAGS_KEY = "OTHER_CFLAGS"
      OTHER_CPLUSPLUSFLAGS_KEY = "OTHER_CPLUSPLUSFLAGS"
      OTHER_LDFLAGS_KEY = "OTHER_LDFLAGS"
      OTHER_SWIFT_FLAGS_KEY = "OTHER_SWIFT_FLAGS"
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

      def replace_module_map_flag(build_settings, flags_key, old_modulemap_names, path)
        flags = build_settings[flags_key]
        if flags
          build_settings[flags_key] = replace_module_map_path(flags, old_modulemap_names, path)
        end
      end

      def replace_module_map_path(flags, old_modulemap_names, path)
        return if flags == nil

        is_flags_string = flags.is_a?(String)
        flags = flags.split(" ") if is_flags_string
        updated_flags = flags
                            .map { |flags_line| flags_line.split(" ") }
                            .flatten
                            .map do |line|
          updated_line = line

          if line.include?("-fmodule-map-file=")
            old_modulemap_names.each do |name|
              if line.include?(name)
                updated_line = "-fmodule-map-file=\"#{path}\""
                break
              end
            end
          end

          updated_line
        end

        is_flags_string ? updated_flags.join(" ") : updated_flags
      end
    end
  end
end
