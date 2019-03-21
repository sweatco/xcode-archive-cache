module XcodeArchiveCache
  module Injection
    class HeadersMover

      include XcodeArchiveCache::Logs

      # @param [Storage] storage
      #
      def initialize(storage)
        @storage = storage
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def delete_headers(node)
        debug("deleting headers of #{node.name}")
        node.native_target.headers_build_phase.files.clear
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def prepare_headers_for_injection(node)
        debug("checking #{node.name} headers")
        file_paths = node.native_target.copy_files_build_phases
                         .map(&:files)
                         .flatten
                         .map {|build_file| get_real_path(build_file)}
                         .compact
                         .uniq
                         .select {|path| File.extname(path) == ".h"}
        debug("found #{file_paths.length} headers")
        storage.store_headers(node, file_paths)
      end

      private

      # @return [Storage]
      #
      attr_reader :storage

      # @param [Xcodeproj::Project::Object::PBXBuildFile] build_file
      #
      # @return [String]
      #
      def get_real_path(build_file)
        if build_file.file_ref.is_a?(Xcodeproj::Project::Object::PBXFileReference)
          build_file.file_ref.real_path.to_s
        end
      end
    end
  end
end
