module XcodeArchiveCache
  module BuildGraph
    class Node

      # @return [String] native target display name
      #
      attr_reader :name

      # @return [Boolean]
      #
      attr_reader :is_root

      # @return [Symbol] should target be rebuilt
      #
      attr_accessor :state

      # @return [String] sha256 of (input files + build settings + dependency shas)
      #
      attr_accessor :sha

      # @return [Array<XcodeArchiveCache::BuildGraph::Node>] dependent nodes
      #
      attr_reader :dependent

      # @return [Array<XcodeArchiveCache::BuildGraph::Node>] dependency nodes
      #
      attr_reader :dependencies

      # @return [Xcodeproj::Project::Object::PBXNativeTarget] corresponding native target
      #
      attr_reader :native_target

      # @return [XcodeArchiveCache::BuildSettings::Container]
      #
      attr_accessor :build_settings

      # @return [Array<Xcodeproj::Project::Object::PBXNativeTarget>]
      #
      attr_reader :targets_injected_to

      # @param [String] name
      # @param [Xcodeproj::Project::Object::PBXNativeTarget] native_target
      # @param [Boolean] is_root
      #
      def initialize(name, native_target, is_root = false)
        @name = name
        @native_target = native_target
        @is_root = is_root
        @dependent = []
        @dependencies = []
        @targets_injected_to = []
        @state = :unknown
      end

      def has_framework_product?
        native_target.product_type == Xcodeproj::Constants::PRODUCT_TYPE_UTI[:framework]
      end

      def has_static_library_product?
        native_target.product_type == Xcodeproj::Constants::PRODUCT_TYPE_UTI[:static_library]
      end

      def has_bundle_product?
        native_target.product_type == Xcodeproj::Constants::PRODUCT_TYPE_UTI[:bundle]
      end

      def has_acceptable_product?
        ACCEPTABLE_PRODUCT_TYPES.include?(native_target.product_type)
      end

      # @return [String]
      #
      def product_file_name
        return nil unless build_settings

        product_name = build_settings[XcodeArchiveCache::BuildSettings::FULL_PRODUCT_NAME_KEY]
        return product_name if product_name

        product_name = native_target.product_reference.name
        if has_framework_product? && product_name
          product_file_name = product_name
        end

        unless product_file_name
          product_file_name = File.basename(native_target.product_reference.real_path)
        end

        product_file_name
      end

      # @return [String]
      #
      def dsym_file_name
        build_settings ? build_settings[XcodeArchiveCache::BuildSettings::DWARF_DSYM_FILE_NAME_KEY] : nil
      end

      # @return [String]
      #
      def modulemap_file_path
        modulemap_file = build_settings[XcodeArchiveCache::BuildSettings::MODULEMAP_FILE_KEY]
        return unless modulemap_file

        Pathname.new(modulemap_file).absolute? ? modulemap_file : File.join(File.dirname(native_target.project.path), modulemap_file)
      end

      # @return [String]
      #
      def swift_objc_interface_header_file
        header_file = build_settings[XcodeArchiveCache::BuildSettings::SWIFT_OBJC_INTERFACE_HEADER_NAME_KEY]
        if header_file == nil
          our_module_name = module_name
          return if our_module_name == nil

          header_file = our_module_name + "-Swift.h"
        end

        header_file
      end

      # @return [String]
      #
      def module_name
        build_settings[XcodeArchiveCache::BuildSettings::PRODUCT_MODULE_NAME_KEY]
      end

      # @return [Array<Node>]
      #         Direct + transitive dependents
      #
      def all_dependent_nodes
        (dependent + dependent.map(&:all_dependent_nodes)).flatten.uniq
      end

      # @return [Array<Node>]
      #
      def subgraph
        ([self] + dependencies + dependencies.map(&:subgraph)).flatten.uniq
      end

      # @return [Bool]
      #
      def waiting_for_rebuild
        state == :waiting_for_rebuild
      end

      def ==(other_node)
        other_node && native_target.uuid == other_node.native_target.uuid && native_target.project == other_node.native_target.project
      end

      def to_s
        sha_string = sha ? sha : "<none>"
        dependent_names = dependent.length > 0 ? dependent.map(&:name).join(", ") : "<none>"
        dependency_names = dependencies.length > 0 ? dependencies.map(&:name).join(", ") : "<none>"
        "#{name}\n\troot: #{is_root}\n\tproduct: #{product_file_name}\n\tsha: #{sha_string}\n\tstate: #{state}\n\tdependent: #{dependent_names}\n\tdependencies: #{dependency_names}"
      end

      private

      ACCEPTABLE_PRODUCT_TYPES = [Xcodeproj::Constants::PRODUCT_TYPE_UTI[:framework],
                                  Xcodeproj::Constants::PRODUCT_TYPE_UTI[:static_library],
                                  Xcodeproj::Constants::PRODUCT_TYPE_UTI[:bundle]].freeze
    end
  end
end
