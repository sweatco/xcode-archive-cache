module XcodeArchiveCache
  module Injection
    class Storage

      # @return [String]
      #
      attr_reader :headers_storage_dir

      # @param [String] path
      #
      def initialize(path)
        @container_dir_path = path
        @headers_storage_dir = File.join(path, HEADERS_STORAGE_ROOT_DIR)

        prepare_container_dir
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      # @param [Array<String>] file_paths
      #
      def store_headers(node, file_paths)
        storage_path = get_headers_storage_path(node)
        return if File.exist?(storage_path)

        FileUtils.mkdir_p(storage_path)
        file_paths.each do |file_path|
          FileUtils.cp(file_path, File.join(storage_path, File.basename(file_path)))
        end

        # TODO: check Xcode behavior
        link_filename = get_headers_symlink_path(node)
        if link_filename && link_filename != storage_path && !File.exist?(link_filename)
          FileUtils.ln_s(storage_path, link_filename)
        end
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

      private

      HEADERS_STORAGE_ROOT_DIR = "include"

      # @return [String]
      #
      attr_reader :container_dir_path

      def prepare_container_dir
        if File.exist?(container_dir_path)
          FileUtils.rm_rf(container_dir_path)
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [String]
      #
      def get_headers_storage_path(node)
        File.join(headers_storage_dir, node.name)
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [String]
      #
      def get_headers_symlink_path(node)
        project_name = node.native_target.project.root_object.name
        if node.name.include?(project_name)
          File.join(headers_storage_dir, project_name)
        end
      end
    end
  end
end