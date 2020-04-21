module XcodeArchiveCache
  module Injection
    class DependencyRemover

      include XcodeArchiveCache::Logs

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      def remove_dependency(prebuilt_node, dependent_target)
        prebuilt_target = prebuilt_node.native_target
        debug("removing #{prebuilt_target.name} from #{dependent_target.display_name}")

        remove_from_dependencies(prebuilt_target, dependent_target)
        remove_from_linking(prebuilt_node, dependent_target)
        remove_from_schemes(prebuilt_target, dependent_target)

        debug("finished removing #{prebuilt_target.name} from #{dependent_target.display_name}")
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      # @return [Boolean]
      #
      def is_linked(prebuilt_node, dependent_target)
        !find_linked(prebuilt_node, dependent_target).empty?
      end

      private

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] prebuilt_target
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      def remove_from_dependencies(prebuilt_target, dependent_target)
        count_before = dependent_target.dependencies.length

        dependent_target.dependencies.delete_if do |dependency|
          if dependency.target
            dependency.target.uuid == prebuilt_target.uuid
          elsif dependency.target_proxy
            dependency.target_proxy.remote_global_id_string == prebuilt_target.uuid
          end
        end

        count_after = dependent_target.dependencies.length
        if count_after == count_before
          debug("found nothing in dependencies")
        else
          debug("removed #{count_before - count_after} dependencies")
        end
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      #
      def remove_from_linking(prebuilt_node, dependent_target)
        debug("product name is #{prebuilt_node.product_file_name}")
        frameworks = find_linked(prebuilt_node, dependent_target)
        debug("found #{frameworks.length} linked products")

        frameworks.each do |framework|
          dependent_target.frameworks_build_phase.remove_file_reference(framework.file_ref)
        end
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] prebuilt_target
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      #
      def remove_from_schemes(prebuilt_target, dependent_target)
        schemes = find_schemes(dependent_target)
        schemes.each do |scheme|
          debug("fixing scheme")
          remove_target_from_scheme(prebuilt_target, scheme)
          scheme.save!
          debug("finished fixing scheme")
        end
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] dependent_target
      # @param [XcodeArchiveCache::BuildGraph::Node] prebuilt_node
      #
      # @return [Array<PBXBuildFile>]
      #
      def find_linked(prebuilt_node, dependent_target)
        return [] unless dependent_target.frameworks_build_phase

        dependent_target.frameworks_build_phase.files.select {|file| file.display_name == prebuilt_node.product_file_name}
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      # @return [Array<Xcodeproj::XCScheme>]
      #
      def find_schemes(target)
        scheme_names = Xcodeproj::Project.schemes(target.project.path)
        scheme_names
            .map {|scheme_name| find_scheme_by_name(target, scheme_name)}
            .compact
            .select {|scheme| scheme_contains_target?(scheme, target)}
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [Xcodeproj::XCScheme] scheme
      #
      def remove_target_from_scheme(target, scheme)
        target_entries = scheme.build_action.entries.select {|entry| scheme_entry_contains_target?(entry, target)}
        return if target_entries.length == 0

        target_entries.each do |entry|
          entry.buildable_references.each do |reference|
            if reference_contains_target?(reference, target)
              debug("removing buildable reference")
              entry.xml_element.delete_element(reference.xml_element)
            end
          end

          if entry.buildable_references.empty?
            debug("removing entry")
            scheme.build_action.xml_element.elements['BuildActionEntries'].delete_element(entry.xml_element)
          end
        end
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      # @param [Xcodeproj::XCScheme] scheme_name
      #
      def find_scheme_by_name(target, scheme_name)
        scheme_path = File.join(Xcodeproj::XCScheme.shared_data_dir(target.project.path),
                                "#{scheme_name}.xcscheme")
        if File.exist?(scheme_path)
          Xcodeproj::XCScheme.new(scheme_path)
        end
      end

      # @param [Xcodeproj::XCScheme] scheme
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def scheme_contains_target?(scheme, target)
        scheme.build_action.entries.each do |entry|
          if scheme_entry_contains_target?(entry, target)
            return true
          end
        end
      end

      # @param [Xcodeproj::XCScheme::BuildAction::Entry] entry
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def scheme_entry_contains_target?(entry, target)
        entry.buildable_references.each do |reference|
          if reference_contains_target?(reference, target)
            return true
          end
        end
      end

      # @param [Xcodeproj::XCScheme::BuildableReference] reference
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      #
      def reference_contains_target?(reference, target)
        reference.target_uuid == target.uuid
      end
    end
  end
end
