module XcodeArchiveCache
  class Config

    include XcodeArchiveCache::Config::DSL

    class Entry

      # @return [String]
      #
      attr_reader :name

      # @return [Array<Target>]
      #
      attr_reader :targets

      # @return [BuildSettings]
      #
      attr_reader :build_settings

      # @return [Storage]
      #
      attr_reader :storage

      # @return [String]
      #
      attr_accessor :destination

      # @return [String]
      #
      attr_accessor :action

      def initialize(name)
        @name = name
        @build_settings = BuildSettings.new
        @storage = Storage.new
        @targets = []
        @file_extname = ""
      end

      # @return [String]
      #
      def file_path
        return name if File.extname(name) == file_extname

        name + file_extname
      end

      def to_s
        "path: #{file_path}\n#{build_settings}\nstorage: #{storage}\ntargets:\n\t#{targets.join("\n\t")}"
      end

      private

      # @return [String]
      #
      attr_reader :file_extname
    end

    class Workspace < Entry
      def initialize(path)
        super(path)
        @file_extname = ".xcworkspace"
      end
    end

    class Project < Entry
      def initialize(path)
        super(path)
        @file_extname = ".xcodeproj"
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

      # @return [Array<String>]
      #
      attr_reader :dependencies

      # @param [String] name
      #
      def initialize(name)
        @name = name
        @dependencies = []
      end

      def to_s
        "name: #{name}, dependencies: #{dependencies.join(", ")}"
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
          raise Informative, "Invalid #{File.basename(path)} file: #{e.message}"
        end
      end

      config
    end

    # @return [Entry]
    #
    attr_reader :current_configuration

    def initialize(&block)
      @current_configuration = nil
      @current_target = nil

      if block
        instance_eval(&block)
      end
    end

    private

    attr_writer :current_configuration

    # @return [Target]
    #
    def current_target
      current_configuration.targets.last
    end
  end
end
