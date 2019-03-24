module XcodeArchiveCache
  class Config
    class Workspace

      # @return [String]
      #
      attr_reader :path

      # @return [Array<Target>]
      #
      attr_reader :targets

      # @return [BuildSettings]
      #
      attr_reader :build_settings

      # @return [Storage]
      #
      attr_reader :storage

      def initialize(path)
        @path = path
        @build_settings = BuildSettings.new
        @storage = Storage.new
        @targets = []
      end

      def to_s
        "path: #{path}\n#{build_settings}\nstorage: #{storage}\ntargets:\n\t#{targets.join("\n\t")}"
      end
    end

    class BuildSettings

      # @return [String]
      #
      attr_accessor :configuration

      # @return [String]
      #
      attr_accessor :derived_data_path

      def to_s
        "configuration: #{configuration}, derived data path: #{derived_data_path}"
      end
    end

    class Storage

      # @return [Symbol]
      #
      attr_accessor :type

      # @return [String]
      #
      attr_accessor :path

      def to_s
        "type: #{type}, path: #{path}"
      end
    end

    class Target

      # @return [String]
      #
      attr_reader :name

      # @return [Array<Dependency>]
      #
      attr_reader :dependencies

      # @param [String] name
      #
      def initialize(name)
        @name = name
        @dependencies = []
      end

      def to_s
        "name: #{name}, dependencies: #{dependencies.join("\n\t")}"
      end
    end

    class Dependency

      # @return [String]
      #
      attr_accessor :name

      # @return [Boolean]
      #
      attr_accessor :pods_target

      # @param [String] name
      # @param [Boolean] pods_target
      #
      def initialize(name, pods_target)
        @name = name
        @pods_target = pods_target
      end

      def to_s
        "name: #{name}, pods target: #{pods_target}"
      end
    end

    # @param [String] path
    #
    def self.from_file(path)
      contents = File.open(path, "r:utf-8", &:read)

      config = Config.new do
        begin
          eval(contents, nil, path)
        rescue Exception => e
          puts "invalid #{File.basename(path)} file: #{e.message}"
        end
      end

      config
    end

    # @return [Workspace]
    #
    attr_reader :current_configuration

    def initialize(&block)
      @current_configuration = nil

      if block
        instance_eval(&block)
      end
    end

    # @param [String] path
    #
    def workspace(path)
      @current_configuration = Workspace.new(path)

      yield
    end

    # @param [String] name
    #
    def configuration(name)
      @current_configuration.build_settings.configuration = name
    end

    # @param [String] path
    #
    def derived_data_path(path)
      @current_configuration.build_settings.derived_data_path = path
    end

    # @param [String] path
    #
    def local_storage(path)
      @current_configuration.storage.type = :local
      @current_configuration.storage.path = path
    end

    # @return [String]
    #
    def target(name)
      @current_target = Target.new(name)
      @current_configuration.targets.push(@current_target)

      yield
    end

    # @param [String] name
    # @param [Boolean] as_pods_target
    #
    def cache(name, as_pods_target: false)
      dependency = Dependency.new(name, as_pods_target)
      @current_target.dependencies.push(dependency)
    end
  end
end
