module XcodeArchiveCache
  module BuildSettings
    class SettingEntry
      attr_reader :name
      attr_reader :modifiers
      attr_reader :full_string

      def initialize(name, modifiers, full_string)
        @name = name
        @modifiers = modifiers
        @full_string = full_string
      end
    end

    class Parser

      def initialize
        @setting_name_regex = Regexp.new("^(?<#{SETTING_NAME_GROUP}>#{SETTING_NAME_CHARACTERS})\s=")
        @setting_value_regex = Regexp.new("^#{SETTING_NAME_CHARACTERS}\s=\s(?<#{SETTING_VALUE_GROUP}>.+)$")
        @setting_entry_regex = create_entry_regex
        @setting_entry_part_regex = Regexp.new("#{SETTING_ENTRY_PART_CHARACTERS}")
        @setting_entry_name_regex = Regexp.new(SETTING_NAME_CHARACTERS)
      end

      # @param [String] string
      #
      # @return [Array<String>]
      #
      def find_all_entries(string)
        return nil if string == nil

        string.scan(setting_entry_regex)
            .map {|entry| 
            parts = entry.scan(setting_entry_part_regex)
            name = parts.first
            modifiers = parts.drop(1)

            name != nil ? SettingEntry.new(name, modifiers, entry) : nil
          }
            .compact
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
      def create_entry_regex(characters = SETTING_ALL_CHARACTERS)
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

      attr_reader :setting_entry_part_regex

      # @return [Regexp]
      #
      attr_reader :setting_entry_name_regex

      SETTING_ALL_CHARACTERS = "[A-Za-z0-9_:]+".freeze
      SETTING_ENTRY_PART_CHARACTERS = "[A-Za-z0-9_]+".freeze
      SETTING_NAME_CHARACTERS = "[A-Z0-9_]+".freeze
      SETTING_NAME_GROUP = "name".freeze
      SETTING_VALUE_GROUP = "value".freeze
    end
  end
end