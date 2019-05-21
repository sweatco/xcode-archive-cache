module XcodeArchiveCache
  module Injection
    class FrameworkEmbedder

      include XcodeArchiveCache::Logs

      # @param [Array<String>] framework_file_paths
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def embed(framework_file_paths, target)
        debug("Embedding frameworks:\n\t#{framework_file_paths.join("\n\t")}")

        frameworks_group = target.project.main_group.new_group("XcodeArchiveCache Frameworks")
        file_references = framework_file_paths.map {|file_path| frameworks_group.new_reference(file_path)}
        embed_frameworks_phase = target.new_copy_files_build_phase("Embed XcodeArchiveCache Frameworks")
        embed_frameworks_phase.symbol_dst_subfolder_spec = :frameworks
        embed_frameworks_phase.run_only_for_deployment_postprocessing = false

        file_references.each do |file_reference|
          build_file = target.project.new(Xcodeproj::Project::Object::PBXBuildFile)
          build_file.file_ref = file_reference
          build_file.settings = {"ATTRIBUTES" => %w(CodeSignOnCopy RemoveHeadersOnCopy)}
          build_file.add_referrer(frameworks_group)
          embed_frameworks_phase.files.push(build_file)
        end
      end
    end
  end
end
