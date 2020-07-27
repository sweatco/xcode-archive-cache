module XcodeArchiveCache
  module BuildGraph
    class NativeTargetFinder

      # @param [Array<Xcodeproj::Project>] projects
      #
      def initialize(projects)
        @all_targets = extract_targets(projects)
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
      def set_platform_name_filter(platform_name)
        @platform_name = platform_name
      end

      # @param [Xcodeproj::Project::Object::PBXTargetDependency] dependency
      #
      # @return [Xcodeproj::Project::Object::PBXNativeTarget]
      #
      def find_for_dependency(dependency)
        # targets from embedded projects are proxied
        target = dependency.target ? dependency.target : dependency.target_proxy.proxied_object
        target.is_a?(Xcodeproj::Project::Object::PBXNativeTarget) ? target : nil
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
      def find_for_product_name(product_name)
        all_targets.select {|native_target| native_target.name == product_name || native_target.product_reference.display_name == product_name}
            .first
      end

      private

      # @return [Array<Xcodeproj::Project::Object::PBXNativeTarget>]
      #
      attr_accessor :all_targets

      # @return [String]
      #
      attr_accessor :platform_name

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
        all_targets.select {|target| target.platform_name == platform_name && target.product_reference.path == path}
      end
    end
  end
end
