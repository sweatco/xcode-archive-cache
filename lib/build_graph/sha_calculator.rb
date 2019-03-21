module XcodeArchiveCache
  module BuildGraph
    class NodeShaCalculator

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def calculate(node)
        return if node.sha

        dependency_shas = []
        node.dependencies.each do |dependency_node|
          calculate(dependency_node)
          dependency_shas.push(dependency_node.sha)
        end

        auxiliary_file = Tempfile.new(node.name)
        save_auxiliary_data(node.build_settings, dependency_shas, auxiliary_file)

        input_paths = list_input_paths(node)
        node.sha = calculate_sha(input_paths + [auxiliary_file.path])
        auxiliary_file.close(true)
      end

      private

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      # @return [Array<String>]
      #         List of input file paths for native target
      #
      def list_input_paths(node)
        inputs = []

        node.native_target.build_phases.each do |build_phase|
          inputs << list_build_phase_inputs(build_phase)
        end

        # file path order should not affect evaluation result
        inputs.flatten.compact.sort
      end

      # @param [Xcodeproj::Project::Object::AbstractBuildPhase] build_phase
      #
      # @return [Array<String>]
      #         List of input file paths for build phase
      #
      def list_build_phase_inputs(build_phase)
        build_phase.files_references.map do |file_ref|
          next unless file_ref.is_a?(Xcodeproj::Project::Object::PBXFileReference)

          begin
            path = file_ref.real_path.to_s
          rescue
            next
          end

          if File.file?(path)
            next path
          elsif File.directory?(path)
            # NOTE: find doesn't follow symlinks, shouldn't we follow them?
            next Find.find(path).select {|found| File.file?(found)}
          end

          []
        end
      end

      # @param [Tempfile] tempfile
      # @param [String] build_settings
      # @param [Array<String>] dependency_shas
      #
      def save_auxiliary_data(build_settings, dependency_shas, tempfile)
        file_contents = build_settings + dependency_shas.join("\n")
        tempfile << file_contents
        tempfile.flush
      end

      # @param [Array<String>] file_paths
      #        File paths to include in resulting sha
      #
      # @return [String] sha256 over specified files
      #
      def calculate_sha(file_paths)
        hash = Digest::SHA256.new
        file_paths.map do |path|
          hash << Digest::SHA256.file(path).hexdigest
        end

        hash.to_s
      end
    end
  end
end
