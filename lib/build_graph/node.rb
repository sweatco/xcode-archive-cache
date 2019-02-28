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
      # @param [Bool] rebuild
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] native_target
      # @param [Array<Node>] dependent
      # @param [Array<Node>] dependencies
      #
      def initialize(name, rebuild, native_target, dependent = nil, dependencies = nil)
        @name = name
        @rebuild = rebuild
        @native_target = native_target
        @dependent = dependent ? dependent : []
        @dependencies = dependencies ? dependencies : []
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