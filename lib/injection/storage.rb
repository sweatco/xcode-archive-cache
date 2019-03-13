module XcodeArchiveCache
  module Injection
    class Storage

      # @param [String] path
      #
      def initialize(path)
        @container_dir_path = path

        prepare_container_dir
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      # @param [Array<String>] file_paths
      #
      def store(node, file_paths)
        storage_path = prepare_storage(node)

        file_paths.each do |path|
          FileUtils.cp_r(path, storage_path)
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def prepare_storage(node)
        path = get_storage_path(node)
        if File.exist?(path)
          raise StandardError.new, "Injection storage path is already busy"
        end

        FileUtils.mkdir_p(path)
        path
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [String]
      #
      def get_storage_path(node)
        File.join(container_dir_path, node.name)
      end

      private

      # @return [String]
      #
      attr_reader :container_dir_path

      def prepare_container_dir
        if File.exist?(container_dir_path)
          FileUtils.rm_rf(container_dir_path)
        end
      end
    end
  end
end