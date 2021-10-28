module XcodeArchiveCache
  module Build
    class ProductExtractor

      include XcodeArchiveCache::Logs

      # @param [String] configuration
      # @param [String] derived_data_path
      #
      def initialize(configuration, derived_data_path)
        @configuration = configuration
        @derived_data_path = derived_data_path
        @shell_executor = XcodeArchiveCache::Shell::Executor.new
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [Array<String>]
      #
      def list_product_contents(built_node)
        file_paths = list_products(built_node)
        file_paths
          .select { |path| File.exist?(path) }
          .map { |path| File.realpath(path) }
      end

      private

      # @return [String]
      # 
      attr_reader :configuration

      # @return [String]
      #
      attr_reader :derived_data_path

      # @return [XcodeArchiveCache::Shell::Executor]
      #
      attr_reader :shell_executor

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [Array<String>]
      #
      def list_products(built_node)
        if built_node.has_framework_product?
          list_framework_products(built_node)
        elsif built_node.has_acceptable_product?
          list_single_product(built_node)
        else
          raise XcodeArchiveCache::Informative, "#{built_node.name} has unsupported product type: #{built_node.native_target.product_type}"
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [Array<String>]
      #
      def list_framework_products(built_node)
        framework_glob = get_main_product_glob(built_node)
        framework_path = Dir.glob(framework_glob).first
        unless framework_path
          raise XcodeArchiveCache::Informative, "Framework product not found for #{built_node.name}"
        end

        framework_dsym_glob = File.join(File.dirname(framework_glob), built_node.dsym_file_name)
        framework_dsym_path = Dir.glob(framework_dsym_glob).first

        bc_symbolmap_paths = list_framework_bc_symbolmaps(framework_path)

        ([framework_path, framework_dsym_path] + bc_symbolmap_paths).flatten.compact
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [Array<String>]
      #
      def list_single_product(built_node)
        product_glob = get_main_product_glob(built_node)
        product_path = Dir.glob(product_glob).first
        unless product_path
          raise XcodeArchiveCache::Informative, "Product of type #{built_node.native_target.product_type} not found for #{built_node.name}"
        end

        paths = [product_path]

        # this one is generated during Swift compilation
        # so we need to cache it as well
        #
        swift_objc_interface_header_glob = get_swift_objc_interface_header_glob(built_node)
        swift_objc_interface_header_path = Dir.glob(swift_objc_interface_header_glob).first
        if swift_objc_interface_header_path
          debug("using Swift-ObjC interface header #{swift_objc_interface_header_path}")
          paths << swift_objc_interface_header_path
        end

        swiftmodule_glob = get_swiftmodule_glob(built_node)
        if swiftmodule_glob
          swiftmodule_path = Dir.glob(swiftmodule_glob).first
          
          if swiftmodule_path
            debug("using swiftmodule #{swiftmodule_path}")
            paths << swiftmodule_path
          end
        end

        modulemap_glob = get_modulemap_glob(built_node)
        if modulemap_glob
          modulemap_path = Dir.glob(modulemap_glob).first

          if modulemap_path
            debug("using modulemap #{modulemap_path}")
            paths << modulemap_path
          end
        end

        paths
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [String]
      #
      def get_main_product_glob(built_node)
        product_names = [File.basename(built_node.native_target.product_reference.path)]
        if built_node.native_target.product_reference.name
          product_names.push(File.basename(built_node.native_target.product_reference.name))
        end

        get_product_glob(product_names.select { |name| File.extname(name).length > 0 })
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [String]
      #
      def get_swift_objc_interface_header_glob(built_node)
        get_product_glob([File.basename(built_node.swift_objc_interface_header_file)])
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [String]
      #
      def get_swiftmodule_glob(built_node)
        if built_node.module_name
          get_product_glob([built_node.module_name + ".swiftmodule"])
        end
      end

      # @param [XcodeArchiveCache::BuildGraph::Node] built_node
      #
      # @return [String]
      #
      def get_modulemap_glob(built_node)
        resulting_modulemap_file_name = built_node.resulting_modulemap_file_name
        if resulting_modulemap_file_name
          get_product_glob([resulting_modulemap_file_name])
        else
          modulemap_file_path = built_node.original_modulemap_file_path
          if modulemap_file_path && File.exist?(modulemap_file_path)
            modulemap_file_name = File.basename(modulemap_file_path)
            get_product_glob([modulemap_file_name])
          end
        end
      end

      # @param [Array<String>] file_names
      #
      # @return [String]
      #
      def get_product_glob(file_names)
        File.join(derived_data_path,
                  "**",
                  "{#{file_names.join(",")}}")
      end

      # @param [String] framework_path
      #
      # @return [Array<String>]
      #
      def list_framework_bc_symbolmaps(framework_path)
        executable_name = File.basename(framework_path, File.extname(framework_path))
        executable_path = File.join(framework_path, executable_name)
        unless File.exist?(executable_path)
          raise XcodeArchiveCache::Informative, "Failed to find executable inside framework: #{framework_path}"
        end

        uuids = list_bc_symbolmap_uuids(executable_path)
        uuids.map { |uuid| find_bc_symbolmap(uuid) }.flatten
      end

      # @param [String] executable_path
      #
      # @return [Array<String>]
      #
      def list_bc_symbolmap_uuids(executable_path)
        begin
          shell_executor.execute_for_output("otool -l #{executable_path} | grep uuid | awk {'print $2'}").split("\n")
        rescue
          []
        end
      end

      # @param [String] uuid
      #
      # @return [String]
      #
      def find_bc_symbolmap(uuid)
        Dir.glob(File.join(derived_data_path, "**", "#{uuid}.bcsymbolmap")).first
      end
    end
  end
end
