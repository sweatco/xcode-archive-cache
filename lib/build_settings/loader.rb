module XcodeArchiveCache
  module BuildSettings

    FULL_PRODUCT_NAME_KEY = "FULL_PRODUCT_NAME".freeze
    DWARF_DSYM_FILE_NAME_KEY = "DWARF_DSYM_FILE_NAME".freeze
    MODULEMAP_FILE_KEY = "MODULEMAP_FILE".freeze
    SWIFT_OBJC_INTERFACE_HEADER_NAME_KEY = "SWIFT_OBJC_INTERFACE_HEADER_NAME".freeze
    SWIFT_MODULE_NAME_KEY = "SWIFT_MODULE_NAME".freeze
    PRODUCT_MODULE_NAME_KEY = "PRODUCT_MODULE_NAME".freeze
    DERIVED_SOURCES_DIR_KEY = "DERIVED_SOURCES_DIR".freeze

    class Container

      # @return [Hash{String => String}]
      #
      attr_reader :all

      # @return [Hash{String => String}]
      #
      attr_reader :filtered

      # @param [Hash{String => String}] all
      # @param [Hash{String => String}] filtered
      #
      def initialize(all, filtered)
        @all = all
        @filtered = filtered
      end

      def [](name)
        all[name]
      end

      def ==(other)
        other && other.all == all && other.filtered == filtered
      end

      # @return [String]
      #
      def filtered_to_string
        filtered.map {|name, value| "#{name} = #{value}"}.join("\n")
      end
    end

    class Loader

      # @param [Xcodebuild::Executor] executor
      #
      def initialize(executor)
        @executor = executor
        @extractor = Extractor.new
      end

      # @param [Array<String>] project_paths
      #
      def load_settings(project_paths)
        paths_without_settings = project_paths.select {|path| get_project_settings(path) == nil}

        threads = paths_without_settings.map do |path|
          Thread.new(path) do |project_path|
            Thread.current.abort_on_exception = true
            [project_path, executor.load_build_settings(project_path)]
          end
        end

        should_fix_settings = executor.set_up_for_simulator?

        threads.each do |thread|
          project_path, all_targets_settings = thread.value
          per_target_settings = extractor.extract_per_target(all_targets_settings, should_fix_settings)
          set_project_settings(project_path, per_target_settings)
        end
      end

      # @param [String] project_path
      # @param [String] target_name
      #
      # @return [Hash{String => String}] build settings for target or nil
      #
      def get_settings(project_path, target_name)
        project_settings = get_project_settings(project_path)
        return nil unless project_settings

        project_settings[target_name]
      end

      private

      SETTINGS = Hash.new

      # @return [XcodeArchiveCache::Xcodebuild::Executor]
      #
      attr_reader :executor

      # @return [XcodeArchiveCache::BuildSettings::Extractor]
      #
      attr_reader :extractor

      # @param [String] path
      #
      # @return [Hash]
      #
      def get_project_settings(path)
        SETTINGS[get_project_key(path)]
      end

      # @param [String] path
      # @param [Hash] per_target_settings
      #
      def set_project_settings(path, per_target_settings)
        SETTINGS[get_project_key(path)] = per_target_settings
      end

      # @param [String] project_path
      #
      # @return [String]
      #
      def get_project_key(project_path)
        "#{project_path}-#{executor.arguments_state}"
      end
    end
  end
end
