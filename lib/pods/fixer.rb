module XcodeArchiveCache
  module Pods
    class Fixer
      def fix_embed_frameworks_script(filename, unpacked_product_dir)
        embed_frameworks_script = File.read(File.absolute_path(filename))
        fixed_script = embed_frameworks_script.gsub("${BUILT_PRODUCTS_DIR}", unpacked_product_dir)
        File.open(filename, "w") {|file| file.puts(fixed_script)}
      end
    end
  end
end