module XcodeArchiveCache
  module Injection
    class PodsXCFrameworkFixer

      include XcodeArchiveCache::Logs

      # @param [XcodeArchiveCache::Injection::Storage] storage
      # @param [XcodeArchive::BuildGraph::NativeTargetFinder] native_target_finder
      # @param [String] configuration_name
      #
      def initialize(storage, native_target_finder, configuration_name)
        @storage = storage
        @native_target_finder = native_target_finder
        @configuration_name = configuration_name
        @shell_executor = XcodeArchiveCache::Shell::Executor.new
        @build_settings_interpolator = XcodeArchiveCache::BuildSettings::StringInterpolator.new
        @checked_targets = []
      end

      # @param [Xcodeproj::Project::Object::PBXAbstractTarget] target
      # @param [XcodeArchiveCache::BuildSettings::Loader] build_settings_loader
      #
      def fix(target, build_settings_loader)
        checked_targets.push(target.equatable_identifier)
        build_settings = build_settings_loader.get_settings(target.project.path, target.display_name)

        debug("fixing #{target.display_name}")
        script_path = find_copy_xcframeworks_script(target, build_settings)
        if script_path != nil
          fix_file(script_path)
          
          unless shell_executor.execute_with_env(script_path, build_settings.all)
            raise XcodeArchiveCache::Informative, "Failed to execute Pods XCFramework script #{script_path}"
          end
        end

        embed_frameworks_script_path = find_embed_frameworks_script(target, build_settings)
        if embed_frameworks_script_path != nil
          fix_file(embed_frameworks_script_path)
        end

        build_configuration = target.find_build_configuration(configuration_name)
        if build_configuration.has_xcconfig?
          fix_xcconfig_recursively(build_configuration.get_xcconfig_path, build_configuration.get_project_dir)
        end

        dependencies = native_target_finder.find_all_dependencies(target)
        dependencies.each do |dependency_target|
          if checked_targets.include?(dependency_target.equatable_identifier)
            next
          end

          fix(dependency_target, build_settings_loader)
        end
      end

      private

      # @return [XcodeArchive::Injection::InjectionStorage]
      #
      attr_reader :storage

      # @return [XcodeArchive::BuildGraph::NativeTargetFinder]
      #
      attr_reader :native_target_finder

      # @return [String]
      #
      attr_reader :configuration_name

      # @return [XcodeArchiveCache::Shell::Executor]
      #
      attr_reader :shell_executor

      # @return [XcodeArchiveCache::BuildSettings::StringInterpolator]
      #
      attr_reader :build_settings_interpolator

      # @return [Array<String>]
      #
      attr_accessor :checked_targets

      # @param [String] path
      # @param [String] project_dir
      #
      def fix_xcconfig_recursively(path, project_dir)
        fix_file(path)
        xcconfig = Xcodeproj::Config.new(path)

        xcconfig.includes.each do |included_xcconfig|
          included_xcconfig_path = File.join(project_dir, included_xcconfig)
          fix_xcconfig_recursively(included_xcconfig_path, project_dir)
        end
      end

      # @param [Xcodeproj::Project::Object::PBXAbstractTarget] target
      # @param [XcodeArchiveCache::BuildSettings::Container] build_settings
      #
      # @return [String]
      #
      def find_copy_xcframeworks_script(target, build_settings)
        target.find_script(build_settings_interpolator, build_settings, "[CP] Copy XCFrameworks")
      end

      # @param [Xcodeproj::Project::Object::PBXAbstractTarget] target
      # @param [XcodeArchiveCache::BuildSettings::Container] build_settings
      #
      # @return [String]
      #
      def find_embed_frameworks_script(target, build_settings)
        target.find_script(build_settings_interpolator, build_settings, "[CP] Embed Pods Frameworks")
      end

      # @param [String] file_path
      #
      def fix_file(file_path)
        debug("fixing #{file_path}")
        contents = File
          .read(file_path)
          .gsub("${PODS_XCFRAMEWORKS_BUILD_DIR}", storage.container_dir_path)

        File.open(file_path, "w") {|file| file.puts(contents)}
      end
    end
  end
end
