module XcodeArchiveCache
  class Config
    module DSL

      # @param [String] name
      #
      def workspace(name)
        self.entry = Workspace.new(name)

        yield
      end

      # @param [String] name
      #
      def project(name)
        self.entry = Project.new(name)

        yield
      end

      # @param [String] name
      #
      def configuration(name)
        entry.configurations.push(Configuration.new(name))

        yield
      end

      # @param [String] name
      #
      def build_configuration(name)
        current_configuration.build_configuration = name
      end

      # @param [String] name
      #
      def action(name)
        current_configuration.action = name
      end

      # @param [String] args
      #
      def xcodebuild_args(args)
        current_configuration.xcodebuild_args = args
      end

      # @param [String] path
      #
      def derived_data_path(path)
        entry.settings.derived_data_path = path
      end

      # @return [String]
      #
      def target(name)
        target = Target.new(name)
        entry.targets.push(target)

        yield
      end

      # @param [String] name
      #
      def cache(name)
        current_target.dependencies.push(name)
      end
    end
  end
end
