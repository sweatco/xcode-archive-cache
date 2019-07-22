module XcodeArchiveCache
  module BuildGraph
    class Builder

      include XcodeArchiveCache::Logs

      # @param [XcodeArchiveCache::Xcodebuild::Executor] xcodebuild_executor
      #
      def initialize(native_target_finder, xcodebuild_executor)
        @build_settings_loader = XcodeArchiveCache::BuildSettings::Loader.new(xcodebuild_executor)
        @native_target_finder = native_target_finder
        @sha_calculator = NodeShaCalculator.new
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependency_target
      #
      # @return [Graph]
      #
      def build_graph(dependent_target, dependency_target)
        native_target_finder.set_platform_name_filter(dependency_target.platform_name)

        graph = Graph.new(dependency_target.project)

        add_to_graph(dependency_target, graph, true)
        load_settings(graph, dependent_target)
        calculate_shas(graph)

        graph
      end

      private

      # @return [XcodeArchiveCache::BuildSettings::Loader]
      #
      attr_accessor :build_settings_loader

      # @return [XcodeArchive::BuildGraph::NativeTargetFinder]
      #
      attr_accessor :native_target_finder

      # @return [XcodeArchiveCache::BuildGraph::NodeShaCalculator]
      #
      attr_accessor :sha_calculator

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [Graph] graph
      # @param [Boolean] is_root
      # @param [Array<String>] target_stack
      #        Stack of native target display names at this level of traverse
      #
      # @return [Node] new or existing node
      #
      def add_to_graph(target, graph, is_root, target_stack = [])
        debug("traversing #{target.display_name}")

        unless target
          raise ArgumentError.new, "Target is required"
        end

        display_name = target.display_name
        existing_node = graph.node_by_name(display_name)
        if existing_node
          debug("already added this one")
          return existing_node
        end

        if target_stack.include?(display_name)
          target_stack.push(display_name)
          raise Informative, "Circular dependency detected: #{target_stack.join(" -> ")}"
        end

        node = graph.node_by_name(display_name)
        if node
          debug("already traversed this one")
          return node
        else
          debug("adding new node")
          node = Node.new(display_name, target, is_root)
          graph.nodes.push(node)
        end

        dependencies = []
        target_stack.push(display_name)

        dependency_targets = target.dependencies.map {|dependency| native_target_finder.find_for_dependency(dependency)} +
            target.frameworks_build_phase.files.map {|file| native_target_finder.find_for_file(file)}

        # PBXNativeTarget has no custom equality check
        deduplicated_targets = dependency_targets.compact.uniq {|dependency_target| dependency_target.uuid + dependency_target.display_name}
        debug("dependency targets: #{deduplicated_targets.map(&:display_name)}")

        deduplicated_targets.each do |dependency_target|
          dependency_node = add_to_graph(dependency_target, graph, false, target_stack)

          unless dependency_node.dependent.include?(node)
            debug("adding #{node.name} as dependent to #{dependency_node.name}")
            dependency_node.dependent.push(node)
          end

          unless dependencies.include?(dependency_node)
            debug("adding #{dependency_node.name} as dependency to #{node.name}")
            dependencies.push(dependency_node)
          end
        end

        target_stack.pop
        node.dependencies.push(*dependencies)

        debug("done with #{target.display_name}")
        node
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def calculate_shas(graph)
        graph.nodes.each do |node|
          debug("calculating sha for #{node.name}")
          sha_calculator.calculate(node)
          debug("sha calculated for #{node.name}: #{node.sha}")
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      def load_settings(graph, dependent_target)
        project_paths = graph.nodes
                            .map {|node| node.native_target}
                            .push(dependent_target)
                            .map {|target| target.project.path}
                            .sort
                            .uniq
        info("loading settings for #{project_paths.length} projects")
        build_settings_loader.load_settings(project_paths)

        graph.dependent_build_settings = get_settings(dependent_target)
        graph.nodes.each {|node| node.build_settings = get_settings(node.native_target)}
      end


      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def get_settings(target)
        info("getting settings for #{target.display_name}")
        build_settings = build_settings_loader.get_settings(target.project.path, target.display_name)
        unless build_settings
          raise Informative, "No build settings loaded for #{target.display_name}"
        end

        build_settings
      end
    end
  end
end
