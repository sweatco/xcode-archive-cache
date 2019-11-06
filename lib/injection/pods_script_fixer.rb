module XcodeArchiveCache
  module Injection
    class PodsScriptFixer

      include XcodeArchiveCache::Logs

      def initialize
        @build_settings_interpolator = XcodeArchiveCache::BuildSettings::StringInterpolator.new
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      # @param [String] products_dir
      #
      def fix_embed_frameworks_script(target, graph, products_dir)
        build_settings = graph.dependent_build_settings
        file_path = find_embed_frameworks_script(target, build_settings)
        return unless file_path

        info("fixing #{file_path}")
        script = File.read(file_path)
        graph.nodes.each do |node|
          relative_product_path = "#{node.native_target.display_name}/#{node.product_file_name}"
          script = script.gsub("${BUILT_PRODUCTS_DIR}/#{relative_product_path}", File.join(products_dir, relative_product_path))
        end

        File.open(file_path, "w") {|file| file.puts(script)}
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

        nil
      end
    end
  end
end
