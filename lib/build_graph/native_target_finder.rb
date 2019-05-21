module XcodeArchiveCache
  module BuildGraph
    class NativeTargetFinder

      # @param [Array<Xcodeproj::Project>] projects
      #
      def initialize(projects)
        @all_targets = projects
                           .map {|project| unnest(project)}
                           .flatten
                           .uniq
                           .map(&:native_targets)
                           .flatten
                           .select {|target| !target.test_target_type? }
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
        dependency.target ? dependency.target : dependency.target_proxy.proxied_object
      end

      # @param [Xcodeproj::Project::Object::PBXBuildFile] file
      #
      # @return [Xcodeproj::Project::Object::PBXNativeTarget]
      #
      def find_for_file(file)
        if file.file_ref.is_a?(Xcodeproj::Project::Object::PBXReferenceProxy)
          project = file.file_ref.remote_ref.container_portal_object
          product_reference_uuid = file.file_ref.remote_ref.remote_global_id_string
          find_with_product_ref_uuid(project, product_reference_uuid)
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
      def find_with_product_ref_uuid(project, uuid)
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
