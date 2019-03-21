module XcodeArchiveCache
  module Xcodebuild
    class Executor

      # @param [String] configuration
      # @param [String] platform
      #
      def initialize(configuration, platform)
        @configuration = configuration
        @platform = platform
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
                 archive_command]
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
                 archive_command]
        command = "#{compile_command(flags)} | xcpretty"
        shell_executor.execute(command, true)
      end

      private

      # @return [String]
      #
      attr_reader :configuration

      # @return [String]
      #
      attr_accessor :platform

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
        "-project #{project_path}"
      end

      # @return [String]
      #
      def configuration_flag
        "-configuration #{configuration}"
      end

      # @return [String]
      #
      def destination_flag
        "-destination 'generic/platform=#{platform}'"
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
        "-scheme #{scheme}"
      end

      # @param [String] path
      #
      # @return [String]
      #
      def derived_data_path_flag(path)
        "-derivedDataPath #{path}"
      end

      # @return [String]
      #
      def show_build_settings_flag
        "-showBuildSettings"
      end

      # @return [String]
      #
      def archive_command
        "archive"
      end
    end
  end
end
