module XcodeArchiveCache
  class Config
    module DSL

      # @param [String] name
      #
      def workspace(name)
        self.current_configuration = Workspace.new(name)

        yield
      end

      # @param [String] name
      #
      def project(name)
        self.current_configuration = Project.new(name)

        yield
      end

      # @param [String] name
      #
      def configuration(name)
        current_configuration.build_settings.configuration = name
      end

      # @param [String] path
      #
      def derived_data_path(path)
        current_configuration.build_settings.derived_data_path = path
      end

      # @param [String] path
      #
      def local_storage(path)
        current_configuration.storage.type = :local
        current_configuration.storage.path = path
      end

      # @return [String]
      #
      def target(name)
        target = Target.new(name)
        current_configuration.targets.push(target)

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
