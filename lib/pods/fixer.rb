module XcodeArchiveCache
  module Pods
    class Fixer

      # @param [String] file_path
      # @param [String] unpacked_product_dir
      #
      def fix_embed_frameworks_script(file_path, unpacked_product_dir)
        embed_frameworks_script = File.read(File.absolute_path(file_path))
        fixed_script = embed_frameworks_script.gsub("${BUILT_PRODUCTS_DIR}", unpacked_product_dir)
        File.open(file_path, "w") {|file| file.puts(fixed_script)}
      end
    end
  end
end