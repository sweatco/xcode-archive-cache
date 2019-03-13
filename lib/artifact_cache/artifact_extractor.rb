module XcodeArchiveCache
  module ArtifactCache
    class ArtifactExtractor

      # @param [XcodeArchiveCache::ArtifactCache::AbstractStorage] storage
      #
      def initialize(storage)
        @storage = storage
        @archiver = Archiver.new
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      # @param [String] destination
      #
      def unpack(node, destination)
        cached_artifact_path = storage.cached_artifact_path(node)
        archiver.unarchive(cached_artifact_path, destination)
      end

      private

      # @return [XcodeArchiveCache::ArtifactCache::AbstractStorage]
      #
      attr_reader :storage

      # @return [XcodeArchiveCache::ArtifactCache::Archiver]
      #
      attr_reader :archiver
    end
  end
end
