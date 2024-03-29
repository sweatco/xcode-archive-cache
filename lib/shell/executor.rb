module XcodeArchiveCache
  module Shell
    class Executor

      # @param [String] command
      # @param [Boolean] print_command
      #
      # @return [String]
      #
      def execute_for_output(command, print_command = false)
        actual_command = extend_for_pipefail(command, print_command)
        output, status = Open3.capture2e(actual_command)

        if status.exitstatus != 0
          raise XcodeArchiveCache::Informative, "#{command}\nexecution failed\n#{output}"
        end

        output
      end

      # @param [String] command
      # @param [Boolean] print_command
      #
      # @return [Boolean] true if command succeeded and returned 0, false otherwise
      #
      def execute(command, print_command = false)
        actual_command = extend_for_pipefail(command, print_command)
        result = system actual_command

        return false if result == nil
        result
      end

      # @param [String] command
      # @param [Hash] env
      #
      # @return [Boolean] true if command succeeded and returned 0, false otherwise
      #
      def execute_with_env(command, env)
        result = system(env, "set -x && '#{command}'")

        return false if result == nil
        result
      end

      private

      # @param [String] command
      # @param [Boolean] print_command
      #
      # @return [String]
      #
      def extend_for_pipefail(command, print_command)
        return command unless contains_pipes?(command)

        "set #{pipefail_flags(print_command: print_command)} && #{command}"
      end

      # @param [String] command
      #
      # @return [Boolean]
      #
      def contains_pipes?(command)
        command.include?("|")
      end

      # @param [Boolean] print_command
      #
      # @return [String]
      #
      def pipefail_flags(print_command)
        flags = ["e", "o pipefail"]
        if print_command
          flags.insert(1, "x")
        end

        "-" + flags.join(" -")
      end
    end
  end
end
