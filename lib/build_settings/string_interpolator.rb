module XcodeArchiveCache
  module BuildSettings
    class StringInterpolator

      def initialize
        @setting_entry_regex = /\$[({][A-Z0-9_]+[)}]/
        @setting_name_regex = /(?<name>[A-Z0-9_]+)/
      end

      # @param [String] string
      # @param [Container] build_settings
      #
      # @return [String]
      #
      def interpolate(string, build_settings)
        names = string.scan(setting_entry_regex)
                    .map {|entry| entry.scan(setting_name_regex).first}
                    .flatten
                    .compact
                    .uniq
        result = string

        names.each do |name|
          value = build_settings[name]
          next unless value

          replacement_regex = Regexp.new("\\$[({]#{name}[)}]")
          result = result.gsub(replacement_regex, value)
        end

        result
      end

      private

      # @return [Regexp]
      #
      attr_accessor :setting_entry_regex

      # @return [Regexp]
      #
      attr_accessor :setting_name_regex
    end
  end
end