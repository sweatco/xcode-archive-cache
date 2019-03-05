module XcodeArchiveCache
  module Xcodebuild
    class Executor

      # @param [String] project_path
      # @param [String] configuration
      # @param [String] platform
      #
        def initialize(project_path, configuration, platform)
          @project_path = project_path
          @configuration = configuration
          @platform = platform
        end

        def load_build_settings
          # TODO: extract command builder
          command = "xcodebuild -project #{@project_path} -configuration #{@configuration} -destination 'generic/platform=#{@platform}' -alltargets -showBuildSettings archive"
          output, status = Open3.capture2e(command)

          if status.exitstatus != 0
            raise StandardError, "xcodebuild execution failed\n#{output}"
          end

          output
        end

        # @param [String] scheme
        # @param [String] derived_data_path
        #
        def build(scheme, derived_data_path)
          system "set -exo pipefail && xcodebuild -project #{@project_path} -configuration #{@configuration} -destination 'generic/platform=#{@platform}' -scheme #{scheme} -derivedDataPath #{derived_data_path} archive | xcpretty"
        end
    end
  end
end
