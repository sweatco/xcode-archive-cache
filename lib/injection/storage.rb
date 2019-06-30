module XcodeArchiveCache
  module Injection
    class Storage

      # @return [String]
      #
      attr_reader :container_dir_path

      # @return [Hash{XcodeArchiveCache::BuildGraph::Node => String}]
      #
      attr_reader :headers_storage_dir_paths

      # @param [String] path
      #
      def initialize(path)
        @container_dir_path = path
        @headers_storage_dir_paths = Hash.new

        prepare_container_dir
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      # @param [String] path
      # @param [Array<String>] file_paths
      #
      def store_headers(node, path, file_paths)
        storage_path = get_full_header_storage_path(path)

        unless File.exist?(storage_path)
          FileUtils.mkdir_p(storage_path)
        end

        file_paths.each do |file_path|
          FileUtils.cp(file_path, File.join(storage_path, File.basename(file_path)))
        end

        save_header_storage_path(storage_path, node)
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      # @param [Array<String>] file_paths
      #
      def store_products(node, file_paths)
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

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [Array<String>]
      #
      def get_headers_storage_paths(node)
        headers_storage_dir_paths[node.name]
      end

      def get_all_headers_storage_paths
        headers_storage_dir_paths
            .map {|_, path| path}
            .flatten
            .uniq
      end

      private

      def prepare_container_dir
        if File.exist?(container_dir_path)
          FileUtils.rm_rf(container_dir_path)
        end
      end

      # @param [String] path
      #
      # @return [String]
      #
      def get_full_header_storage_path(path)
        File.absolute_path(path, container_dir_path)
      end

      # @param [String] path
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def save_header_storage_path(path, node)
        paths = get_headers_storage_paths(node) || []
        containing_directory = File.dirname(path)
        unless paths.include?(containing_directory)
          paths.push(containing_directory)
          set_all_headers_storage_paths(paths, node)
        end
      end

      # @param [String] paths
      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def set_all_headers_storage_paths(paths, node)
        headers_storage_dir_paths[node.name] = paths
      end
    end
  end
end