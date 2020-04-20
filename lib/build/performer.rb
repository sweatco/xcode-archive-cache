module XcodeArchiveCache
  module Build
    class Performer

      include XcodeArchiveCache::Logs

      # @param [String] derived_data_path
      #
      def initialize(xcodebuild_executor, derived_data_path)
        @xcodebuild_executor = xcodebuild_executor
        @derived_data_path = derived_data_path
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

          build_result = xcodebuild_executor.build(target.project.path, target.name, derived_data_path)
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
    end
  end
end
