require 'open3'

module XcodeArchiveCache
  module Xcodebuild
    class Executor
      # @param [String] project_path
      # @param [String] configuration
      def load_build_settings(project_path, configuration)
        # TODO: extract command builder
        command = "xcodebuild -project #{project_path} -configuration #{configuration} -destination 'generic/platform=iOS' -alltargets -showBuildSettings archive"
        output, status = Open3.capture2e(command)

        if status.exitstatus != 0
          raise StandardError, "xcodebuild execution failed\n#{output}"
        end

        output
      end
    end
  end
end