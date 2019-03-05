module XcodeArchiveCache
  module BuildGraph
    class Builder
      # @param [Logger] logger
      #
      def initialize(logger)
        @logger = logger
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] root_target
      #
      # @return [Graph]
      #
      def build_graph(root_target)
        graph = Graph.new(root_target.project)
        add_to_graph(root_target, graph)
        graph
      end

      private

      # @return [Logger]
      #
      attr_accessor :logger

      # @param [Xcodeproj::Project::Object::PBXTargetDependency] target
      # @param [Graph] graph
      # @param [Array<String>] target_stack
      #        Stack of native target names at this level of traverse
      #
      # @return [Node] added or edited node
      #
      def add_to_graph(target, graph, target_stack = [])
        @logger.debug("traversing #{target.display_name}")

        unless target
          raise ArgumentError, "Target is required"
        end

        display_name = target.display_name
        if target_stack.include?(display_name)
          target_stack.push(display_name)
          raise StandardError, "Circular dependency detected: #{target_stack.join(" -> ")}"
        end

        node = graph.node_by_name(display_name)
        if node
          @logger.debug("already traversed this one")
          return node
        else
          @logger.debug("adding new node")
          node = Node.new(display_name, target)
          graph.nodes.push(node)
        end

        dependencies = []
        target_stack.push(display_name)

        target.dependencies.each do |dependency|
          dependency_target =  target.project.native_targets.select {|some_native_target| some_native_target.uuid == dependency.native_target_uuid}.first
          dependency_node = add_to_graph(dependency_target, graph, target_stack)

          @logger.debug("adding #{node.name} as dependent to #{dependency_node.name}")
          dependency_node.dependent.push(node)

          @logger.debug("adding #{dependency_node.name} as dependency to #{node.name}")
          dependencies.push(dependency_node)
        end

        target_stack.pop
        node.dependencies.push(*dependencies)

        @logger.debug("done with #{target.display_name}")
        node
      end
    end
  end
end
