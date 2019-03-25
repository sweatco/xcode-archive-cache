module XcodeArchiveCache
  module Injection
    class PodsScriptFixer

      include XcodeArchiveCache::Logs

      def initialize
        @build_settings_interpolator = XcodeArchiveCache::BuildSettings::StringInterpolator.new
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [XcodeArchiveCache::BuildSettings::Container] build_settings
      # @param [String] products_dir
      #
      def fix_embed_frameworks_script(target, build_settings, products_dir)
        file_path = find_embed_frameworks_script(target, build_settings)
        return unless file_path

        info("fixing #{file_path}")
        original_script = File.read(file_path)
        fixed_script = original_script.gsub("${BUILT_PRODUCTS_DIR}", products_dir)
        File.open(file_path, "w") {|file| file.puts(fixed_script)}
      end

      private

      # @return [XcodeArchiveCache::BuildSettings::StringInterpolator]
      #
      attr_reader :build_settings_interpolator

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [XcodeArchiveCache::BuildSettings::Container] build_settings
      #
      # @return [String]
      #
      def find_embed_frameworks_script(target, build_settings)
        target.shell_script_build_phases.each do |phase|
          if phase.display_name == "[CP] Embed Pods Frameworks"
            return build_settings_interpolator.interpolate(phase.shell_script, build_settings)
                       .gsub(/^"|"$/, "")
                       .strip
          end
        end
      end
    end
  end
end