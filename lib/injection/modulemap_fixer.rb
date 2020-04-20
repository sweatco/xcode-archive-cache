module XcodeArchiveCache
  module Injection

    class ModulemapFixer

      # @param [Storage] storage
      #
      def initialize(storage)
        @storage = storage
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] node
      #
      def fix_modulemap(node)
        return unless node.has_static_library_product?

        modulemap_file_path = node.modulemap_file_path
        return if modulemap_file_path == nil

        injected_modulemap_file_path = storage.get_modulemap_path(node)
        return if injected_modulemap_file_path == nil

        swift_objc_interface_header_file_name = node.swift_objc_interface_header_file
        return if swift_objc_interface_header_file_name == nil

        # add generated header to modulemap to make Swift stuff available module users
        #
        storage_path = storage.get_storage_path(node)
        header_path = File.join(storage_path, swift_objc_interface_header_file_name)
        return unless File.exist?(header_path)

        File.open(injected_modulemap_file_path, "a") do |modulemap_file|
          modulemap_file.puts "\nmodule #{node.module_name}.Swift {\n"
          modulemap_file.puts "  header \"#{header_path}\"\n"
          modulemap_file.puts "  requires objc\n"
          modulemap_file.puts "}\n"
        end
      end

      private

      # @return [Storage]
      #
      attr_accessor :storage
    end
  end
end
