module XcodeArchiveCache
  module BuildGraph
    class Graph
      # @return [Array<XcodeArchiveCache::BuildGraph::Node>] graph nodes
      #
      attr_reader :nodes

      # @return [Xcodeproj::Project] project

      attr_reader :project

      def initialize(project)
        @nodes = []
        @project = project
      end

      # @param [String] name
      #        Native target display name
      #
      def node_by_name(name)
        nodes.select {|node| node.name == name}.first
      end

      def to_s
        nodes.map(&:to_s).join("\n")
      end
    end
  end
end
