module XcodeArchiveCache
  module Xcodebuild
    class Executor

      # @param [String] configuration
      # @param [String] platform
      #
      def initialize(configuration, platform)
        @configuration = configuration
        @platform = platform
      end

      # @param [String] project_path
      #
      def load_build_settings(project_path)
        # TODO: extract command builder
        command = "xcodebuild -project #{project_path} -configuration #{configuration} -destination 'generic/platform=#{platform}' -alltargets -showBuildSettings archive"
        output, status = Open3.capture2e(command)

        if status.exitstatus != 0
          raise StandardError, "xcodebuild execution failed\n#{output}"
        end

        output
      end

      # @param [String] project_path
      # @param [String] scheme
      # @param [String] derived_data_path
      #
      def build(project_path, scheme, derived_data_path)
        system "set -exo pipefail && xcodebuild -project #{project_path} -configuration #{configuration} -destination 'generic/platform=#{platform}' -scheme #{scheme} -derivedDataPath #{derived_data_path} archive | xcpretty"
      end

      private

      # @return [String]
      #
      attr_reader :configuration

      # @return [String]
      #
      attr_accessor :platform
    end
  end
end
