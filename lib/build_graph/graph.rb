module XcodeArchiveCache
  module BuildGraph
    class Graph
      # @return [Array<Node>] graph nodes
      #
      attr_reader :nodes

      # @return [Xcodeproj::Project] project
      #
      attr_reader :project

      # @return [XcodeArchiveCache::BuildSettings::Container] root target build settings
      #
      attr_accessor :dependent_build_settings

      # @param [Xcodeproj::Project] project
      #
      def initialize(project)
        @nodes = []
        @project = project
      end

      # @param [String] name
      #        Native target display name
      #
      # @return [XcodeArchiveCache::BuildGraph::Node]
      #
      def node_by_name(name)
        nodes.select {|node| node.name == name}.first
      end

      def add_multiple_nodes(new_nodes)
        @nodes += new_nodes
      end

      # @return [XcodeArchiveCache::BuildGraph::Node]
      #
      def root_node
        nodes.select {|node| node.is_root}.first
      end

      def to_s
        nodes.map(&:to_s).join("\n")
      end
    end
  end
end
