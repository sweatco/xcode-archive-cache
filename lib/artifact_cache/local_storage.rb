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

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      # @param [String] path
      #
      def store(node, path)
        archive_path = path_inside_cache_dir(node)
        archive_directory = File.expand_path("..", archive_path)
        unless File.exist?(archive_directory)
          FileUtils.mkdir_p(archive_directory)
        end

        archiver.archive(path, archive_path)
        save_state(node, archive_path)
      end

      private

      # @return [String]
      #
      attr_reader :cache_dir_path

      # @return [XcodeArchiveCache::ArtifactCache::Archiver]
      #
      attr_reader :archiver

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [String]
      #
      def path_inside_cache_dir(node)
        File.join(cache_dir_path, node.name, node.sha)
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      # @param [String] archive_path
      #
      # Simply writes build settings and dependency SHAs to a file
      # Useful for debugging and investigation purposes
      #
      def save_state(node, archive_path)
        state_file_path = archive_path + ".state"

        if File.exist?(state_file_path)
          raise ArgumentError.new, "State file already exists: #{state_file_path}"
        end

        dependency_shas = node.dependencies
                              .map {|dependency| dependency.name + ": " + dependency.sha}
                              .join("\n")
        state = node.build_settings.filtered_to_string + "\n\nDependencies:\n" + dependency_shas + "\n"

        File.write(state_file_path, state)
      end
    end
  end
end
