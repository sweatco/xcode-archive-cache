module XcodeArchiveCache
  module ArtifactCache
    class AbstractStorage
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [String] cached artifact path, nil if no cached artifact found
      #
      def cached_artifact_path(node)
        nil
      end
    end
  end
end