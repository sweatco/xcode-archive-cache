module XcodeArchiveCache
  module Modulemap
    class HeaderPathFixer

      include XcodeArchiveCache::Logs

      # @param [Storage] storage
      #
      def initialize(storage)
        @storage = storage
        @header_path_extractor = HeaderPathExtractor.new
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def fix_modulemap(node)
        return unless node.has_static_library_product?

        injected_modulemap_file_path = storage.get_modulemap_path(node)
        return if injected_modulemap_file_path == nil

        file_handler = FileHandler.new

        modulemap_dir = File.dirname(injected_modulemap_file_path)
        modulemap_lines = file_handler.read_modulemap_lines(injected_modulemap_file_path)

        updated_lines = modulemap_lines.map do |line|
          declaration = header_path_extractor.extract_header_declaration(line)
          next line unless declaration

          # absolute paths depend on machine and derived data dir
          #
          full_header_path = header_path_extractor.get_full_header_path(modulemap_dir, declaration.path)
          should_replace = Pathname.new(declaration.path).absolute? || !File.exist?(full_header_path)
          next line unless should_replace

          header_file_name = File.basename(declaration.path)
          injected_header_path = File.join(modulemap_dir, header_file_name)
          next line if injected_header_path == declaration.path

          if File.exist?(injected_header_path)
            debug("substituting #{declaration.path} with #{injected_header_path} in #{File.basename(injected_modulemap_file_path)}")
            "#{declaration.type}\"#{injected_header_path}\""
          else
            error("failed to substitute missing header #{declaration.path} with another missing header in #{File.basename(injected_modulemap_file_path)}")
            error("leaving the path as it is")
            line
          end
        end

        file_handler.write_modulemap_lines(updated_lines, injected_modulemap_file_path)
      end

      private

      # @return [Storage]
      #
      attr_accessor :storage

      # @return [XcodeArchiveCache::Modulemap::HeaderPathExtractor]
      #
      attr_accessor :header_path_extractor
    end
  end
end
