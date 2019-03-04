require 'xcodeproj'
require_relative 'graph'
require_relative 'node'

module XcodeArchiveCache
  module BuildGraph
    class Builder
      # @param [Logger] logger
      #
      def initialize(logger)
        @logger = logger
      end

      # @param [Xcodeproj::Project] project
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] root_target
      #
      # @return [Graph]
      #
      def build_graph(project, root_target)
        graph = Graph.new
        add_to_graph(root_target, project, graph)
        graph
      end

      private

      # @return [Logger]
      #
      attr_accessor :logger

      # @param [Xcodeproj::Project::Object::PBXTargetDependency] object
      # @param [Xcodeproj::Project] project
      # @param [Graph] graph
      # @param [Array<String>] target_stack
      #        Stack of native target names at this level of traverse
      #
      # @return [Node] added or edited node
      #
      def add_to_graph(object, project, graph, target_stack = [])
        @logger.debug("traversing #{object.display_name}")

        native_target = object.is_a?(Xcodeproj::Project::Object::PBXNativeTarget) ? object : find_native_target(project, object.native_target_uuid)
        unless native_target
          raise ArgumentError, "Native target not found for #{object.display_name} in #{project.path}"
        end

        display_name = native_target.display_name
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
          node = Node.new(display_name, native_target)
          graph.nodes.push(node)
        end

        dependencies = []
        target_stack.push(display_name)

        native_target.dependencies.each do |dependency|
          dependency_node = add_to_graph(dependency, project, graph, target_stack)

          @logger.debug("adding #{node.name} as dependent to #{dependency_node.name}")
          dependency_node.dependent.push(node)

          @logger.debug("adding #{dependency_node.name} as dependency to #{node.name}")
          dependencies.push(dependency_node)
        end

        target_stack.pop
        node.dependencies.push(*dependencies)

        @logger.debug("done with #{object.display_name}")
        node
      end

      # @param [Xcodeproj::Project] project
      # @param [String] native_target_uuid
      #
      # @return [Xcodeproj::Project::Object::PBXNativeTarget]
      #
      def find_native_target(project, native_target_uuid)
        project.native_targets.select {|some_native_target| some_native_target.uuid == native_target_uuid}.first
      end
    end
  end
end
