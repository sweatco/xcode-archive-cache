module XcodeArchiveCache
  module BuildGraph
    class NativeTargetFinder

      # @param [Array<Xcodeproj::Project>] projects
      # @param [String] build_configuration_name
      #
      def initialize(projects, build_configuration_name)
        @all_targets = extract_targets(projects)
        @build_configuration_name = build_configuration_name
        @interpolator = XcodeArchiveCache::BuildSettings::StringInterpolator.new

        setup_product_name_to_target_mapping
      end

      # @param [Array<Xcodeproj::Project>] projects
      #
      # @return [Array<Xcodeproj::Project::Object::PBXNativeTarget>]
      #
      def extract_targets(projects)
        projects
          .map {|project| unnest(project)}
          .flatten
          .sort_by(&:path)
          .inject([]) {|unique, current| unique.last && unique.last.path == current.path ? unique : unique + [current]}
          .map(&:native_targets)
          .flatten
          .select {|target| !target.test_target_type?}
      end

      # @param [String] platform_name
      #
      # @return [Array<Xcodeproj::Project::Object::PBXNativeTarget>]
      #
      def set_platform_name_filter(platform_name)
        @platform_name = platform_name
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      # @return [Array<Xcodeproj::Project::Object::PBXNativeTarget>]
      #
      def find_native_dependencies(target)
        direct_dependencies = target
                                .dependencies
                                .map {|dependency| find_for_dependency(dependency)}
        linked_dependencies = find_linked_dependencies(target)
        join(direct_dependencies, linked_dependencies)
      end

      # @param [Xcodeproj::Project::Object::PBXAbstractTarget] target
      #
      # @return [Array<Xcodeproj::Project::Object::PBXAbstractTarget>]
      #
      def find_all_dependencies(target)
        direct_dependencies = target
                                .dependencies
                                .map {|dependency| find_any_for_dependency(dependency)}
        linked_dependencies = []
        
        if target.is_a?(Xcodeproj::Project::Object::PBXNativeTarget) 
          linked_dependencies = find_linked_dependencies(target)
        end

        join(direct_dependencies, linked_dependencies)
      end

      # @param [Xcodeproj::Project::Object::PBXTargetDependency] dependency
      #
      # @return [Xcodeproj::Project::Object::PBXNativeTarget]
      #
      def find_for_dependency(dependency)
        # targets from embedded projects are proxied
        target = find_any_for_dependency(dependency)
        target.is_a?(Xcodeproj::Project::Object::PBXNativeTarget) ? target : nil
      end

      def find_any_for_dependency(dependency)
        target = dependency.target ? dependency.target : dependency.target_proxy.proxied_object
        target && target.platform_name == platform_name ? target : nil
      end

      # @param [Xcodeproj::Project::Object::PBXBuildFile] file
      #
      # @return [Xcodeproj::Project::Object::PBXNativeTarget]
      #
      def find_for_file(file)
        if file.file_ref.is_a?(Xcodeproj::Project::Object::PBXReferenceProxy)
          product_reference_uuid = file.file_ref.remote_ref.remote_global_id_string
          target = find_with_product_ref_uuid(product_reference_uuid)
          if target == nil
            project = file.file_ref.remote_ref.container_portal_object
            target = find_in_project(project, product_reference_uuid)

            # allow all targets from this project
            # to be linked to that exact project
            #
            # otherwise, injection will operate on different Xcodeproj::Project objects
            # resulting to only the last target being actually removed
            #
            @all_targets += extract_targets([project])
          end

          if target == nil
            raise Informative, "Target for #{file.file_ref.path} not found"
          end

          target
        elsif file.file_ref.is_a?(Xcodeproj::Project::Object::PBXFileReference)
          # products of sibling project targets are added as PBXFileReferences
          targets = find_with_product_path(file.file_ref.path)
          if targets.length > 1
            raise Informative, "Found more than one target with product #{File.basename(file.file_ref.path)} in:\n#{targets.map(&:project)}"
          end

          targets.first
        end
      end

      # @param [String] product_name
      #
      # @return [Xcodeproj::Project::Object::PBXNativeTarget]
      #
      def find_for_product_name(product_name)
        canonical = all_targets
          .select {|native_target| native_target.name == product_name || native_target.product_reference.display_name == product_name}
          .first
        
        parsed = @product_name_to_target[product_name]

        canonical ? canonical : parsed
      end

      private

      # @return [Array<Xcodeproj::Project::Object::PBXNativeTarget>]
      #
      attr_accessor :all_targets

      # @return [String]
      #
      attr_accessor :platform_name

      # @return [String]
      #
      attr_reader :build_configuration_name

      def setup_product_name_to_target_mapping
        @product_name_to_target = Hash.new

        @all_targets.each do |target|
          build_settings = target.find_build_configuration(build_configuration_name).build_settings
          full_settings = build_settings
          full_settings[XcodeArchiveCache::BuildSettings::TARGET_NAME_KEY] = target.name
          product_name = @interpolator.interpolate(build_settings[XcodeArchiveCache::BuildSettings::PRODUCT_NAME_KEY], full_settings)

          next if product_name == nil

          product_name_extension = ""
          case target.product_type
          when Xcodeproj::Constants::PRODUCT_TYPE_UTI[:framework]
            product_name_extension = ".framework"
          when Xcodeproj::Constants::PRODUCT_TYPE_UTI[:static_library]
            product_name_extension = ".a"
          end

          full_product_name = "#{product_name}#{product_name_extension}"
          @product_name_to_target[full_product_name] = target
        end
      end

      # @param [Xcodeproj::Project] project
      #
      # @return [Array<Xcodeproj::Project>]
      #
      #         Project + subprojects at all levels of nesting
      #
      def unnest(project)
        nested_projects = project.files
                              .select {|file_ref| File.extname(file_ref.path) == ".xcodeproj" && File.exist?(file_ref.real_path)}
                              .map {|file_ref| Xcodeproj::Project.open(file_ref.real_path)}
        subnested_projects = nested_projects.map {|nested_project| unnest(nested_project)}.flatten
        [project] + nested_projects + subnested_projects
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      # @return [Array<Xcodeproj::Project::Object::PBXNativeTarget>]
      #
      def find_linked_dependencies(target)
        target
          .frameworks_build_phase
          .files
          .map {|file| find_for_file(file)}
      end

      # @param [Array<Xcodeproj::Project::Object::PBXAbstractTarget>] direct_dependencies
      # @params [Array<Xcodeproj::Project::Object::PBXNativeTarget>] linked_dependencies
      #
      # @return [Array<Xcodeproj::Project::Object::PBXAbstractTarget>]
      #
      def join(direct_dependencies, linked_dependencies)
        (direct_dependencies + linked_dependencies)
          .compact
          .uniq(&:equatable_identifier)
      end

      # @param [String] uuid
      #
      # @return [Xcodeproj::Project::Object::PBXNativeTarget]
      #
      def find_with_product_ref_uuid(uuid)
        all_targets.select {|target| target.product_reference.uuid == uuid}.first
      end

      # @param [Xcodeproj::Project] project
      # @param [String] uuid
      #
      # @return [Xcodeproj::Project::Object::PBXNativeTarget]
      #
      def find_in_project(project, uuid)
        project.native_targets.select {|target| target.product_reference.uuid == uuid}.first
      end

      # @param [String] path
      #
      # @return [Array<Xcodeproj::Project::Object::PBXNativeTarget>]
      #
      def find_with_product_path(path)
        canonical = all_targets.select {|target| target.platform_name == platform_name && target.product_reference.path == path }
        parsed = @product_name_to_target[File.basename(path)]

        if canonical.length > 0
          canonical
        elsif parsed
          [parsed]
        else
          []
        end
      end
    end
  end
end
