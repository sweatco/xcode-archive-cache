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

        # remove from "Link binary with libraries"
        debug("product name is #{prebuilt_node.product_file_name}")
        frameworks = dependent_target.frameworks_build_phase.files.select {|file| file.display_name == prebuilt_node.product_file_name}
        debug("found #{frameworks.length} linked products")

        frameworks.each do |framework|
          dependent_target.frameworks_build_phase.remove_file_reference(framework.file_ref)
        end

        # remove from "Target dependencies"
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

        debug("finished removing #{prebuilt_target.name} from #{dependent_target.display_name}")
      end
    end
  end
end
