module XcodeArchiveCache
  module Injection
    class PodsScriptFixer

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [String] products_dir
      #
      def fix_embed_frameworks_script(target, products_dir)
        file_path = find_embed_frameworks_script(target)
        return unless file_path

        original_script = File.read(file_path)
        fixed_script = original_script.gsub("${BUILT_PRODUCTS_DIR}", products_dir)
        File.open(file_path, "w") {|file| file.puts(fixed_script)}
      end

      private

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      # @return [String]
      #
      def find_embed_frameworks_script(target)
        target.shell_script_build_phases.each do |phase|
          if phase.display_name == "[CP] Embed Pods Frameworks"
            return phase.shell_script
                       .gsub("${SRCROOT}", File.dirname(target.project.path))
                       .gsub(/^"|"?$/, "")
                       .strip
          end
        end
      end
    end
  end
end