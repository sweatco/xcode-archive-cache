module XcodeArchiveCache
  module Injection
    class FrameworkEmbedder

      include XcodeArchiveCache::Logs

      def initialize
        @shell_executor = XcodeArchiveCache::Shell::Executor.new
      end

      # @param [Array<String>] framework_file_paths
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def embed(framework_file_paths, target)
        return unless target.product_type == Xcodeproj::Constants::PRODUCT_TYPE_UTI[:application]

        dynamic_framework_file_paths = framework_file_paths.select do |path|
          binary_name = File.basename(path, ".framework")
          binary_path = File.join(path, binary_name)
          shell_executor.execute("file #{binary_path} | grep dynamic")
        end

        return if dynamic_framework_file_paths.length == 0

        debug("Embedding frameworks:\n\t#{dynamic_framework_file_paths.join("\n\t")}")

        frameworks_group = target.project.main_group.new_group("XcodeArchiveCache Frameworks")
        file_references = dynamic_framework_file_paths.map {|file_path| frameworks_group.new_reference(file_path)}
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

      private

      # @return [XcodeArchiveCache::Shell::Executor]
      #
      attr_reader :shell_executor
    end
  end
end
