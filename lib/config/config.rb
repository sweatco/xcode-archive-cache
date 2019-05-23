module XcodeArchiveCache
  class Config

    include XcodeArchiveCache::Config::DSL

    class Entry

      # @return [String]
      #
      attr_reader :name

      # @return [Array<Configuration>]
      #
      attr_reader :configurations

      # @return [String]
      #
      attr_accessor :active_configuration_name

      # @return [Array<Target>]
      #
      attr_reader :targets

      # @return [Settings]
      #
      attr_reader :settings

      # @return [Storage]
      #
      attr_reader :storage

      def initialize(name)
        @name = name
        @configurations = []
        @active_configuration_name = nil
        @settings = Settings.new
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

      # @return [Configuration]
      #
      def active_configuration
        configuration = configurations.select{|config| config.name == active_configuration_name }.first
        if configuration == nil
          raise Informative, "Found no configuration with name \"#{active_configuration_name}\""
        end

        configuration
      end

      def to_s
        "path: #{file_path}\nactive configuration: #{active_configuration_name}\nconfigurations:\n\t#{configurations.join("\n\t")}\n#{settings}\nstorage: #{storage}\ntargets:\n\t#{targets.join("\n\t")}"
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

    class Configuration
      # @return [String]
      #
      attr_reader :name

      # @return [String]
      #
      attr_accessor :build_configuration

      # @return [String]
      #
      attr_accessor :action

      # @return [String]
      #
      attr_accessor :xcodebuild_args

      # @param [String] name
      #
      def initialize(name)
        @name = name
        @action = "archive"
      end

      def to_s
        "#{name}, build configuration: #{build_configuration}, action: #{action}, xcodebuild args: \"#{xcodebuild_args}\""
      end
    end

    class Settings
      # @return [String]
      #
      attr_accessor :derived_data_path

      # @return [String]
      #
      attr_accessor :destination

      def to_s
        "destination: #{destination}, derived data path: #{derived_data_path}"
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
        "#{type}, path: #{path}"
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
        "#{name}, dependencies: #{dependencies.join(", ")}"
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
    attr_reader :entry

    def initialize(&block)
      @entry = nil
      @current_target = nil

      if block
        instance_eval(&block)
      end
    end

    private

    attr_writer :entry

    # @return [Configuration]
    #
    def current_configuration
      entry.configurations.last
    end

    # @return [Target]
    #
    def current_target
      entry.targets.last
    end
  end
end
