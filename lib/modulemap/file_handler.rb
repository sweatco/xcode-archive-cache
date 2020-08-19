module XcodeArchiveCache
  module Modulemap
    class FileHandler
      # @param [String] modulemap_path
      #
      # @return [Array<String>]
      #
      def read_modulemap_lines(modulemap_path)
        File.read(modulemap_path).split("\n")
      end

      # @param [Array<String>] lines
      # @param [String] modulemap_path
      #
      def write_modulemap_lines(lines, modulemap_path)
        File.open(modulemap_path, "w") { |file| file.puts lines.join("\n") }
      end
    end
  end
end
