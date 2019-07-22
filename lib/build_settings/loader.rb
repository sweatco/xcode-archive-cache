module XcodeArchiveCache
  module BuildSettings

    FULL_PRODUCT_NAME_KEY = "FULL_PRODUCT_NAME".freeze
    DWARF_DSYM_FILE_NAME_KEY = "DWARF_DSYM_FILE_NAME".freeze

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

      # @param [Xcodebuild::Executor.new] executor
      #
      def initialize(executor)
        @executor = executor
        @extractor = Extractor.new
        @settings = Hash.new
      end

      # @param [Array<String>] project_paths
      #
      def load_settings(project_paths)
        paths_without_settings = project_paths.select {|path| settings[path] == nil}

        threads = paths_without_settings.map do |path|
          Thread.new(path) do |project_path|
            Thread.current.abort_on_exception = true
            [project_path, executor.load_build_settings(project_path)]
          end
        end

        threads.each do |thread|
          project_path, all_targets_settings = thread.value
          settings[project_path] = extractor.extract_per_target(all_targets_settings)
        end
      end

      # @param [String] project_path
      # @param [String] target_name
      #
      # @return [Hash{String => String}] build settings for target or nil
      #
      def get_settings(project_path, target_name)
        return nil unless settings[project_path]

        settings[project_path][target_name]
      end

      private

      # @return [XcodeArchiveCache::Xcodebuild::Executor]
      #
      attr_reader :executor

      # @return [XcodeArchiveCache::BuildSettings::Extractor]
      #
      attr_reader :extractor

      # @return [Hash{String => Hash}]
      #
      attr_reader :settings
    end
  end
end
