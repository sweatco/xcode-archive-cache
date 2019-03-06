module XcodeArchiveCache
  module BuildSettings
    class Fixer

      # @param [String] configuration_name
      # @param [XcodeArchiveCache::ArtifactCache::ArtifactExtractor] artifact_extractor
      # @param [Logger] logger
      #
      def initialize(configuration_name, artifact_extractor, logger)
        @configuration_name = configuration_name
        @artifact_extractor = artifact_extractor
        @logger = logger
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def fix(graph)
        graph.nodes.each do |node|
          propagate_node(node)
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      def add_as_prebuilt_framework(prebuilt_node, dependent_target)
        build_configuration = dependent_target.build_configurations.select {|configuration| configuration.name == configuration_name}.first
        unless build_configuration
          raise ArgumentError.new, "#{configuration_name} build configuration not found on target #{node.name}"
        end

        artifact_location = artifact_extractor.unpacked_artifact_location(prebuilt_node)
        search_path = path_to_search_path(artifact_location)
        logger.debug("using search path #{search_path}")
        add_framework_search_path(build_configuration, search_path)

        headers_search_path = path_to_iquote(artifact_location, prebuilt_node)
        logger.debug("using headers search path #{headers_search_path}")
        add_headers_search_path(build_configuration, headers_search_path)

        remove_framework_dependency(prebuilt_node.native_target, dependent_target)

        logger.debug("added prebuilt framework at #{search_path} to #{configuration_name} configuration of #{dependent_target.display_name}")
      end

      private

      # @return [String]
      #
      attr_reader :configuration_name

      # @return [XcodeArchiveCache::ArtifactCache::ArtifactExtractor]
      # 
      attr_reader :artifact_extractor

      # @return [Logger]
      # 
      attr_reader :logger

      FRAMEWORK_SEARCH_PATHS_KEY = "FRAMEWORK_SEARCH_PATHS"
      OTHER_CFLAGS_KEY = "OTHER_CFLAGS"
      INHERITED_SETTINGS_VALUE = "$(inherited)"

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def propagate_node(node)
        logger.debug("propagating #{node.name}")

        if node.rebuild
          # node should be rebuilt, so we shouldn't point dependants to the cached artifact
          # because there's no such artifact
          #
          logger.debug("#{node.name} should be rebuilt, skipping")
          return
        end

        if node.has_framework_product?
          logger.debug("product is a framework")

          # add to framework search paths of dependents
          propagate_framework(node, node)

          # remove headers so they don't cause non-module includes
          delete_headers(node)
        elsif node.has_static_library_product?
          logger.debug("product is a static library")

          # TODO: add to library search paths of dependents
          raise StandardError.new, "Static libraries not supported yet"
        else
          raise ArgumentError.new, "Unsupported cached product type for #{node.name}: #{node.native_target.product_type}"
        end

        logger.debug("done propagating #{node.name}")
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [XcodeArchiveCache::BuildGraph::Node] dependent_node
      #
      def propagate_framework(prebuilt_node, dependent_node)
        dependent_node.dependent.each do |node|
          propagate_prebuilt_framework(prebuilt_node, node)
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def propagate_prebuilt_framework(prebuilt_node, node)
        if node.rebuild
          add_as_prebuilt_framework(prebuilt_node, node.native_target)
        end

        # add to upper level dependencies too
        propagate_framework(prebuilt_node, node)
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] search_path
      #
      def add_framework_search_path(build_configuration, search_path)
        framework_search_paths = build_configuration.build_settings[FRAMEWORK_SEARCH_PATHS_KEY]
        if framework_search_paths && framework_search_paths.length > 0
          if framework_search_paths.is_a?(String)
            framework_search_paths = [framework_search_paths, search_path]
          elsif framework_search_paths.is_a?(Array)
            framework_search_paths += [search_path]
          else
            raise StandardError.new, "Framework search paths value is neither string nor array: #{framework_search_paths.class}"
          end
        else
          framework_search_paths = [INHERITED_SETTINGS_VALUE, search_path]
        end

        build_configuration.build_settings[FRAMEWORK_SEARCH_PATHS_KEY] = framework_search_paths
      end

      # @param [Xcodeproj::Project::Object::XCBuildConfiguration] build_configuration
      # @param [String] search_path
      #
      def add_headers_search_path(build_configuration, search_path)
        cflags = build_configuration.build_settings[OTHER_CFLAGS_KEY]
        if cflags && cflags.length > 0
          if cflags.is_a?(String)
            cflags = [cflags, search_path]
          elsif cflags.is_a?(Array)
            cflags += [search_path]
          else
            raise StandardError.new, "Other C flags value is neither string nor array: #{cflags.class}"
          end
        else
          cflags = [INHERITED_SETTINGS_VALUE, search_path]
        end

        build_configuration.build_settings[OTHER_CFLAGS_KEY] = cflags
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] prebuilt_target
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      def remove_framework_dependency(prebuilt_target, dependent_target)
        # remove from "Link binary with libraries"
        frameworks = dependent_target.frameworks_build_phase.files.select do |file|
          file.display_name == prebuilt_target.product_reference.name
        end

        if frameworks.length > 0
          frameworks.each do |framework|
            dependent_target.frameworks_build_phase.remove_file_reference(framework.file_ref)
          end
        end

        # remove from "Target dependencies"
        dependent_target.dependencies.delete_if {|dependency| dependency.target.uuid == prebuilt_target.uuid}
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def delete_headers(node)
        logger.debug("deleting headers of #{node.name}")
        node.native_target.headers_build_phase.files.clear
      end

      # @param [String] path
      # @return [String]
      #
      def path_to_search_path(path)
        "\"#{path}\""
      end

      # @param [String] path
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      # @return [String]
      #
      def path_to_iquote(path, node)
        if node.has_framework_product?
          search_path = File.join(path, File.basename(node.native_target.product_reference.name), "Headers")
          "-iquote \"#{search_path}\""
        end
      end
    end
  end
end
