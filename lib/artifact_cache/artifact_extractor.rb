require 'fileutils'

require_relative 'archiver'

module XcodeArchiveCache
  module ArtifactCache
    class ArtifactExtractor

      # @param [XcodeArchiveCache::ArtifactCache::AbstractStorage] storage
      # @param [String] target_dir_path
      #
      def initialize(storage, target_dir_path)
        @storage = storage
        @target_dir_path = target_dir_path
        @archiver = Archiver.new
      end

      # @param [XcodeArchiveCache::BuildGraph::Graph] graph
      #
      def unpack_available(graph)
        graph.nodes.each do |node|
          unless node.rebuild
            unpack_single(node)
          end
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def unpacked_artifact_location(node)
        File.join(@target_dir_path, node.name)
      end

      private

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def unpack_single(node)
        cached_artifact_path = @storage.cached_artifact_path(node)
        destination = unpacked_artifact_location(node)

        if File.exists?(destination)
          FileUtils.rm_rf(destination)
        end

        FileUtils.mkdir_p(destination)
        @archiver.unarchive(cached_artifact_path, destination)
      end

      # @return [XcodeArchiveCache::ArtifactCache::AbstractStorage]
      #
      attr_reader :storage

      # @return [String]
      #
      attr_reader :target_dir_path
    end
  end
end
