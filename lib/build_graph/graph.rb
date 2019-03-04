module XcodeArchiveCache
  module BuildGraph
    class Graph
      # @return [Array<XcodeArchiveCache::BuildGraph::Node>] graph nodes
      #
      attr_accessor :nodes

      def initialize
        @nodes = []
      end

      # @param [String] name
      #        Native target display name
      #
      def node_by_name(name)
        @nodes.select {|node| node.name == name}.first
      end

      def to_s
        @nodes.map(&:to_s).join("\n")
      end
    end
  end
end
