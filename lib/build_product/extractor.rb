module XcodeArchiveCache
  module BuildProduct
    class Extractor

      # @param [String] configuration
      # @param [String] derived_data_path
      #
      def initialize(configuration, derived_data_path)
        @configuration = configuration
        @derived_data_path = derived_data_path
      end

      def copy_product(root_target_name, built_node, destination)
        built_product_path = product_path(root_target_name, built_node)
        file_paths = list_products(built_product_path, built_node)
        file_paths.select {|path| File.exist?(path)}.map {|path| File.symlink?(path) ? File.readlink(path) : path}.each do |path|
          destination_path = File.join(destination, File.basename(path))
          FileUtils.cp_r(path, destination_path)
        end
      end

      private

      # @return [String]
      # 
      attr_reader :configuration

      # @return [String]
      #
      attr_reader :derived_data_path

      # @param [String] root_target_name
      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      def product_path(root_target_name, built_node)
        if has_framework_product(built_node)
          root_product_path = File.join(derived_data_path, "ArchiveIntermediates",
                                        root_target_name,
                                        "BuildProductsPath",
                                        "#{configuration}-#{built_node.native_target.sdk}")
          if root_target_name == built_node.name
            return root_product_path
          else
            return File.join(root_product_path, built_node.name)
          end
        elsif has_static_library_product(built_node)
        else
        end
      end

      # @param [String] path
      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      def list_products(path, built_node)
        if has_framework_product(built_node)
          framework_path = File.join(path, "*.framework")
          dsym_path = framework_path + ".dSYM"
          bcsymbolmap_path = File.join(path, "*.bcsymbolmap")
          Dir.glob(bcsymbolmap_path) + Dir.glob(framework_path) + Dir.glob(dsym_path)
        end
      end

      def has_framework_product(built_node)
        built_node.native_target.product_type == Xcodeproj::Constants::PRODUCT_TYPE_UTI[:framework]
      end

      def has_static_library_product(built_node)
        built_node.native_target.product_type == Xcodeproj::Constants::PRODUCT_TYPE_UTI[:static_library]
      end
    end
  end
end
