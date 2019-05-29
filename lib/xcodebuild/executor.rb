module XcodeArchiveCache
  module Xcodebuild
    ARCHIVE_ACTION = "archive"
    GENERIC_DESTINATION = "generic"

    class Executor
      # @param [String] configuration
      # @param [String] platform
      # @param [String] destination
      # @param [String] action
      # @param [String] args
      #
      def initialize(configuration, platform, destination, action, args)
        @configuration = configuration
        @platform = platform
        @destination = destination
        @action = action
        @args = args
        @shell_executor = XcodeArchiveCache::Shell::Executor.new
      end

      # @param [String] project_path
      #
      def load_build_settings(project_path)
        flags = [project_flag(project_path),
                 configuration_flag,
                 destination_flag,
                 all_targets_flag,
                 show_build_settings_flag,
                 args,
                 action]
        command = compile_command(flags)
        shell_executor.execute_for_output(command)
      end

      # @param [String] project_path
      # @param [String] scheme
      # @param [String] derived_data_path
      #
      def build(project_path, scheme, derived_data_path)
        flags = [project_flag(project_path),
                 configuration_flag,
                 destination_flag,
                 scheme_flag(scheme),
                 derived_data_path_flag(derived_data_path),
                 args,
                 action]
        command = "#{compile_command(flags)} | xcpretty"
        shell_executor.execute(command, true)
      end

      private

      # @return [String]
      #
      attr_reader :configuration

      # @return [String]
      #
      attr_reader :platform

      # @return [String]
      #
      attr_reader :destination

      # @return [String]
      #
      attr_reader :action

      # @return [String]
      #
      attr_reader :args

      # @return [XcodeArchiveCache::Shell::Executor]
      #
      attr_accessor :shell_executor

      # @param [Array<String>] flags
      #
      # @return [String]
      #
      def compile_command(flags)
        "xcodebuild #{flags.join(" ")}"
      end

      # @param [String] project_path
      #
      # @return [String]
      #
      def project_flag(project_path)
        "-project '#{project_path}'"
      end

      # @return [String]
      #
      def configuration_flag
        "-configuration '#{configuration}'"
      end

      # @return [String]
      #
      def destination_flag
        # archives can only be made with generic destination
        #
        inferred_destination = action == ARCHIVE_ACTION ? GENERIC_DESTINATION : destination
        destination_specifier = inferred_destination == GENERIC_DESTINATION ? "generic/platform=#{platform}" : inferred_destination
        "-destination '#{destination_specifier}'"
      end

      # @return [String]
      #
      def all_targets_flag
        "-alltargets"
      end

      # @param [String] scheme
      #
      # @return [String]
      #
      def scheme_flag(scheme)
        "-scheme '#{scheme}'"
      end

      # @param [String] path
      #
      # @return [String]
      #
      def derived_data_path_flag(path)
        "-derivedDataPath '#{path}'"
      end

      # @return [String]
      #
      def show_build_settings_flag
        "-showBuildSettings"
      end
    end
  end
end
