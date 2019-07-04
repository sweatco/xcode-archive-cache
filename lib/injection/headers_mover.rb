module XcodeArchiveCache
  module Injection
    class HeadersMover

      include XcodeArchiveCache::Logs

      # @param [Storage] storage
      #
      def initialize(storage)
        @storage = storage
        @build_settings_interpolator = XcodeArchiveCache::BuildSettings::StringInterpolator.new
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def prepare_headers_for_injection(node)
        debug("checking #{node.name} headers")
        header_count = 0

        node.native_target.copy_files_build_phases.each do |build_phase|
          file_paths = build_phase.files
                           .map {|build_file| get_real_path(build_file)}
                           .compact
                           .uniq
                           .select {|path| File.extname(path) == ".h"}
          destination_path = get_destination_dir_path(node, build_phase)
          storage.store_headers(node, destination_path, file_paths)

          header_count += file_paths.length
        end

        debug("found #{header_count} headers")
      end

      private

      # @return [Storage]
      #
      attr_reader :storage

      # @return [XcodeArchiveCache::BuildSettings::StringInterpolator]
      #
      attr_reader :build_settings_interpolator

      # @param [Xcodeproj::Project::Object::PBXBuildFile] build_file
      #
      # @return [String]
      #
      def get_real_path(build_file)
        if build_file.file_ref.is_a?(Xcodeproj::Project::Object::PBXFileReference)
          build_file.file_ref.real_path.to_s
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      # @param [Xcodeproj::Project::Object::PBXCopyFilesBuildPhase] build_phase
      #
      # @return [String]
      #
      def get_destination_dir_path(node, build_phase)
        build_settings_interpolator.interpolate(build_phase.dst_path, node.build_settings)
      end
    end
  end
end
