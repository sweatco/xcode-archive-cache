module XcodeArchiveCache
  module BuildSettings
    class Parser

      def initialize
        @setting_name_regex = Regexp.new("^(?<#{SETTING_NAME_GROUP}>#{SETTING_NAME_CHARACTERS})\s=")
        @setting_value_regex = Regexp.new("^#{SETTING_NAME_CHARACTERS}\s=\s(?<#{SETTING_VALUE_GROUP}>.+)$")
        @setting_entry_regex = create_entry_regex
        @setting_entry_name_regex = Regexp.new(SETTING_NAME_CHARACTERS)
      end

      # @param [String] string
      #
      # @return [Array<String>]
      #
      def find_all_names(string)
        string.scan(setting_entry_regex)
            .map {|entry| entry.scan(setting_entry_name_regex).first}
            .flatten
            .compact
            .uniq
      end

      # @param [String] string
      #
      # @return [String]
      #
      def parse_name(string)
        match = setting_name_regex.match(string)
        return nil unless match

        match[SETTING_NAME_GROUP]
      end

      # @param [String] string
      #
      # @return [String]
      #
      def parse_value(string)
        match = setting_value_regex.match(string)
        return nil unless match

        match[SETTING_VALUE_GROUP]
      end

      # @param [String] characters
      #
      # @return [Regexp]
      #
      def create_entry_regex(characters = SETTING_NAME_CHARACTERS)
        Regexp.new("\\$[({]#{characters}[)}]")
      end

      private

      # @return [Regexp]
      #
      attr_reader :setting_name_regex

      # @return [Regexp]
      #
      attr_reader :setting_value_regex

      # @return [Regexp]
      #
      attr_reader :setting_entry_regex

      # @return [Regexp]
      #
      attr_reader :setting_entry_name_regex

      SETTING_NAME_CHARACTERS = "[A-Z0-9_]+".freeze
      SETTING_NAME_GROUP = "name".freeze
      SETTING_VALUE_GROUP = "value".freeze
    end
  end
end