module XcodeArchiveCache
  module BuildGraph
    class RebuildListComposer

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def compose(graph)
        # top level targets will trigger rebuild of their dependencies
        # 
        graph.nodes.select(&:rebuild).map(&:topmost_dependent_nodes).flatten.uniq
      end
    end
  end
end