module XcodeArchiveCache
  module Logs

    private

    COMMON_LOGGER = Logger.new(STDOUT)
    ERROR_LOGGER = Logger.new(STDERR)

    public

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
      ERROR_LOGGER.error(message)
    end
  end
end
