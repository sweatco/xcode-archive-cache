module XcodeArchiveCache
  module Build
    class Performer

      include XcodeArchiveCache::Logs

      # @param [String] derived_data_path
      #
      def initialize(xcodebuild_executor, derived_data_path, workspace_path=nil)
        @xcodebuild_executor = xcodebuild_executor
        @derived_data_path = derived_data_path
        @workspace_path = workspace_path
      end

      # @param [Xcodeproj::Project::Object::PBXNativeTarget] target
      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def rebuild_missing(target, graph)
        should_rebuild_anything = should_rebuild?(graph)
        if should_rebuild_anything
          rebuild_list = graph.nodes
                             .select(&:waiting_for_rebuild)
                             .map(&:name)
                             .join(", ")
          info("going to rebuild:\n#{rebuild_list}")

          if workspace_path
            build_result = xcodebuild_executor.build_from_workspace(workspace_path, target.name, derived_data_path)
          else
            build_result = xcodebuild_executor.build_from_project(target.project.path, target.name, derived_data_path)
          end

          unless build_result
            raise StandardError.new, "Failed to perform rebuild"
          end
        else
          info("no need to rebuild anything")
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def should_rebuild?(graph)
        graph.root_node.state != :unpacked
      end

      private

      # @return [String]
      #
      attr_reader :derived_data_path

      # @return [XcodeArchiveCache::Xcodebuild::Executor]
      #
      attr_reader :xcodebuild_executor

      # @return [String]
      #
      attr_reader :workspace_path
    end
  end
end
