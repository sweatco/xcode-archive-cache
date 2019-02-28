require 'xcodeproj'

module XcodeArchiveCache
  module BuildGraph
    class Node
      # @return [String] native target display name
      #
      attr_reader :name

      # @return [Bool] should target be rebuilt
      #
      attr_accessor :rebuild

      # @return [String] sha256 of (input files + build settings + dependency shas)
      #
      attr_accessor :sha

      # @return [Array<XcodeArchiveCache::BuildGraph::Node>] dependent nodes
      #
      attr_reader :dependent

      # @return [Array<XcodeArchiveCache::BuildGraph::Node>] dependency nodes
      #
      attr_reader :dependencies

      # @return [Xcodeproj::Project::Object::PBXNativeTarget] corresponding native target
      #
      attr_reader :native_target

      # @return [String] filtered `xcodebuild -showBuildSettings` output
      #
      attr_accessor :build_settings

      # @param [String] name
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] native_target
      #
      def initialize(name, native_target)
        @name = name
        @native_target = native_target
        @dependent = []
        @dependencies = []
      end

      # @return [Array<XcodeArchiveCache::BuildGraph::Node>]
      #         List of nodes which have no dependants and depend on us,
      #         directly or transitively
      #
      def topmost_dependent_nodes
        # kind of weird, but: "node depends on itself"
        return [self] if dependent.length == 0

        dependent.map(&:topmost_dependent_nodes).flatten
      end

      def to_s
        sha_string = @sha ? @sha : "<none>"
        dependent_names = @dependent.length > 0 ? @dependent.map(&:name).join(", ") : "<none>"
        dependency_names = @dependencies.length > 0 ? @dependencies.map(&:name).join(", ") : "<none>"
        "#{@name}\n\tsha: #{sha_string}\n\trebuild: #{@rebuild}\n\tdependent: #{dependent_names}\n\tdependencies: #{dependency_names}"
      end
    end
  end
end