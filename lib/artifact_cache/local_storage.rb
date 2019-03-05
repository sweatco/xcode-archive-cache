module XcodeArchiveCache
  module ArtifactCache
    class LocalStorage < AbstractStorage

      # @param [String] cache_dir_path
      #
      def initialize(cache_dir_path)
        @cache_dir_path = cache_dir_path
        @archiver = Archiver.new
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [String] cached artifact path, nil if no artifact found in cache dir
      #
      def cached_artifact_path(node)
        path = path_inside_cache_dir(node)
        File.exist?(path) ? path : nil
      end

      def store(node, path)
        archive_path = path_inside_cache_dir(node)
        archive_directory = File.expand_path("..", archive_path)
        unless File.exist?(archive_directory)
          FileUtils.mkdir_p(archive_directory)
        end

        @archiver.archive(path, archive_path)
      end

      private

      def path_inside_cache_dir(node)
        File.join(@cache_dir_path, node.name, node.sha)
      end
    end
  end
end
