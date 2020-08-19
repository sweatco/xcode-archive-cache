module XcodeArchiveCache
  module Modulemap
    class HeaderPathDeclaration
      # @return [String]
      #
      attr_reader :type

      # @return [String]
      #
      attr_reader :path

      # @param [String] type
      # @param [String] path
      #
      def initialize(type, path)
        @type = type
        @path = path
      end
    end

    class HeaderPathExtractor

      include XcodeArchiveCache::Logs

      # @param [String] modulemap_path
      #
      # @return [Array<String>]
      #
      def extract_all_paths(modulemap_path)
        modulemap_dir = File.dirname(modulemap_path)
        modulemap_lines = FileHandler.new.read_modulemap_lines(modulemap_path)
        header_paths = []

        modulemap_lines.each do |line|
          header_declaration = extract_header_declaration(line)
          if header_declaration
            header_paths << get_full_header_path(modulemap_dir, header_declaration.path)
          end
        end

        debug("modulemap header paths: #{header_paths}")

        header_paths
      end

      # @param [String] modulemap_dir
      # @param [String] path
      #
      # @return [String]
      #
      def get_full_header_path(modulemap_dir, path)
        Pathname.new(path).absolute? ? path : File.join(modulemap_dir, path)
      end

      # @param [String] line
      #
      # @return [XcodeArchiveCache::Modulemap::HeaderPathDeclaration]
      #
      def extract_header_declaration(line)
        if line.include?("header") && !line.include?("exclude")
          components = line.split("\"")
          HeaderPathDeclaration.new(components[0], components[1])
        end
      end
    end
  end
end
