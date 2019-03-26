module XcodeArchiveCache
  module BuildSettings
    class StringInterpolator

      def initialize
        @parser = Parser.new
      end

      # @param [String] string
      # @param [Container] build_settings
      #
      # @return [String]
      #
      def interpolate(string, build_settings)
        names = parser.find_all_names(string)
        result = string

        names.each do |name|
          value = build_settings[name]
          next unless value

          replacement_regex = parser.create_entry_regex(name)
          result = result.gsub(replacement_regex, value)
        end

        result
      end

      private

      # @return [Parser]
      #
      attr_accessor :parser
    end
  end
end