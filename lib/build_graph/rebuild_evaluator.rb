module XcodeArchiveCache
  module BuildGraph
    class RebuildEvaluator

      # @param [XcodeArchiveCache::ArtifactCache::AbstractStorage] cache_storage
      #
      def initialize(cache_storage)
        @cache_storage = cache_storage
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def evaluate(node)
        return if node.rebuild != nil

        # we include dependency shas in every node sha calculation,
        # so if some dependency changes, that change propagates
        # all the way to the top level
        #
        node.rebuild = @cache_storage.cached_artifact_path(node) == nil
      end

      private

      # @return [XcodeArchiveCache::ArtifactCache::AbstractStorage]
      #
      attr_reader :cache_storage
    end
  end
end