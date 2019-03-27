module XcodeArchiveCache
  module Logs

    private

    COMMON_LOGGER = Logger.new(STDOUT)
    COMMON_LOGGER.formatter = proc do |_, _, _, msg|
      "#{msg}\n"
    end

    ERROR_LOGGER = Logger.new(STDERR)
    ERROR_LOGGER.formatter = COMMON_LOGGER.formatter

    public

    def set_log_level(level)
      case level
      when "info"
        COMMON_LOGGER.level = Logger::Severity::INFO
      when "verbose"
        COMMON_LOGGER.level = Logger::Severity::DEBUG
      when "nothing"
        COMMON_LOGGER.level = Logger::Severity::ERROR
      else
        COMMON_LOGGER.level = Logger::Severity::ERROR
      end
    end

    # @param [String] message
    #
    def debug(message)
      COMMON_LOGGER.debug(message)
    end

    # @param [String] message
    #
    def info(message)
      COMMON_LOGGER.info(message)
    end

    # @param [String] message
    #
    def error(message)
      ERROR_LOGGER.fatal(message)
    end
  end
end
