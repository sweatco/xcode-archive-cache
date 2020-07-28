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
                           .map { |build_file| get_real_path(build_file) }
                           .compact
                           .uniq
                           .select { |path| File.extname(path) == ".h" }
          destination_path = get_destination_dir_path(node, build_phase)
          storage.store_headers(node, destination_path, file_paths)

          header_count += file_paths.length
        end

        if node.has_static_library_product?
          headers_file_paths = node.native_target
                                   .headers_build_phase
                                   .files
                                   .select { |file| file.settings && file.settings["ATTRIBUTES"].include?("Public") }
                                   .map { |header| get_real_path(header) }
                                   .uniq
          storage.store_default_headers(node, headers_file_paths)

          header_count += headers_file_paths.length
        end

        modulemap_file_path = node.modulemap_file_path
        if modulemap_file_path && File.exist?(modulemap_file_path)
          header_file_paths = enumerate_modulemap_headers(modulemap_file_path)
          storage.store_default_headers(node, header_file_paths)
          header_count += header_file_paths.length

          storage.store_modulemap(node)
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

      def enumerate_modulemap_headers(modulemap_path)
        modulemap_dir = File.dirname(modulemap_path)
        modulemap_lines = File.read(modulemap_path).split("\n")
        header_paths = []

        modulemap_lines.each do |line|
          if line.include?("header") && !line.include?("exclude")
            header_name = line.split("\"")[1]
            header_paths << File.join(modulemap_dir, header_name)
          end
        end

        debug "modulemap header paths: #{header_paths}"

        header_paths
      end
    end
  end
end
