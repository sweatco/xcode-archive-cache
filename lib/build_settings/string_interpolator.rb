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
        return nil if string == nil

        entries = parser.find_all_entries(string)
        result = string

        entries.each do |entry|
          value = build_settings[entry.name]
          next unless value

          modified_value = modify_setting_value(value, entry.modifiers)
          result = result.gsub(entry.full_string, modified_value)
        end

        result
      end

      private

      # @return [Parser]
      #
      attr_accessor :parser

      def modify_setting_value(value, modifiers)
        modified_value = value

        modifiers.each do |modifier|
          case modifier
          when "c99extidentifier"
            modified_value = modified_value.gsub(/[-\s]/, "_")
          else
          end
        end

        modified_value
      end
    end
  end
end
