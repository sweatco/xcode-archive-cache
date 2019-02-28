require_relative 'abstract_storage'

module XcodeArchiveCache
  module ArtifactCache
    class LocalStorage < AbstractStorage
      # @param [String] cache_dir_path
      #
      def initialize(cache_dir_path)
        @cache_dir_path = cache_dir_path
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [String] cached artifact path, nil if no artifact found in cache dir
      #
      def cached_artifact_path(node)
        path = path_inside_cache_dir(node)
        File.exist?(path) ? path : nil
      end

      private

      def path_inside_cache_dir(node)
        File.join(@cache_dir_path, node.name, node.sha)
      end
    end
  end
end