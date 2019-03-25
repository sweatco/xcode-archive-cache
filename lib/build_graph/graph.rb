module XcodeArchiveCache
  module BuildGraph
    class Graph
      # @return [Array<Node>] graph nodes
      #
      attr_reader :nodes

      # @return [Xcodeproj::Project] project
      #
      attr_reader :project

      # @return [XcodeArchiveCache::BuildSettings::Container] root target build settings
      #
      attr_reader :dependent_build_settings

      # @param [Xcodeproj::Project] project
      # @param [XcodeArchiveCache::BuildSettings::Container] dependent_build_settings
      #
      def initialize(project, dependent_build_settings)
        @nodes = []
        @project = project
        @dependent_build_settings = dependent_build_settings
      end

      # @param [String] name
      #        Native target display name
      #
      def node_by_name(name)
        nodes.select {|node| node.name == name}.first
      end

      def to_s
        nodes.map(&:to_s).join("\n")
      end
    end
  end
end
