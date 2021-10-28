module XcodeArchiveCache
  module Injection
    class PodsScriptFixer

      include XcodeArchiveCache::Logs

      # @param [XcodeArchiveCache::Injection::Storage] storage
      #
      def initialize(storage)
        @storage = storage
        @build_settings_interpolator = XcodeArchiveCache::BuildSettings::StringInterpolator.new
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def fix_embed_frameworks_script(target, graph)
        build_settings = graph.dependent_build_settings
        file_path = find_embed_frameworks_script(target, build_settings)
        return unless file_path

        fix_script(file_path, graph)
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def fix_copy_resources_script(target, graph)
        build_settings = graph.dependent_build_settings
        file_path = find_copy_resources_script(target, build_settings)
        return unless file_path

        fix_script(file_path, graph)
      end

      private

      # @return [XcodeArchiveCache::Injection::Storage]
      #
      attr_reader :storage

      # @return [XcodeArchiveCache::BuildSettings::StringInterpolator]
      #
      attr_reader :build_settings_interpolator

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [XcodeArchiveCache::BuildSettings::Container] build_settings
      #
      # @return [String]
      #
      def find_embed_frameworks_script(target, build_settings)
        target.find_script(build_settings_interpolator, build_settings, "[CP] Embed Pods Frameworks")
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [XcodeArchiveCache::BuildSettings::Container] build_settings
      #
      # @return [String]
      #
      def find_copy_resources_script(target, build_settings)
        target.find_script(build_settings_interpolator, build_settings, "[CP] Copy Pods Resources")
      end

      # @param [String] file_path
      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def fix_script(file_path, graph)
        info("fixing #{file_path}")
        script = File.read(file_path)
        graph.nodes.each do |node|
          product_path = File.join(storage.get_storage_path(node), node.product_file_name)
          script = script.gsub(Regexp.new("\"[^\"]+\/#{node.product_file_name}\""), "\"#{product_path}\"")
        end

        File.open(file_path, "w") {|file| file.puts(script)}
      end
    end
  end
end
