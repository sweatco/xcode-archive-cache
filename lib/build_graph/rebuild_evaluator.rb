module XcodeArchiveCache
  module BuildGraph
    class RebuildEvaluator

      # @param [XcodeArchiveCache::ArtifactCache::AbstractStorage] cache_storage
      #
      def initialize(cache_storage)
        @cache_storage = cache_storage
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def evaluate_build_graph(graph)
        return if graph.root_node.state != :unknown

        # DFS over graph, evaluating dependencies first
        #
        stack = [graph.root_node]

        while stack.length > 0
          last_node = stack.last

          if last_node.state == :evaluating_dependencies
            # dependencies were evaluated, we're good to go
            evaluate(last_node)
            stack.delete_at(stack.length - 1)
          elsif last_node.state == :unknown
            last_node.state = :evaluating_dependencies
            stack += last_node.dependencies.select { |dependency| dependency.state == :unknown }
          else
            stack.delete_at(stack.length - 1)
          end
        end
      end

      private

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def evaluate(node)
        has_dependencies_waiting_for_rebuild = node.dependencies
                                                   .reduce(false) { |rebuild, dependency| rebuild || dependency.waiting_for_rebuild }

        # we include dependency shas in every node sha calculation,
        # so if some dependency changes, that change propagates
        # all the way to the top level
        #
        if has_dependencies_waiting_for_rebuild || cache_storage.cached_artifact_path(node) == nil
          node.state = :waiting_for_rebuild
        else
          node.state = :exists_in_cache
        end
      end

      # @return [XcodeArchiveCache::ArtifactCache::AbstractStorage]
      #
      attr_reader :cache_storage
    end
  end
end
