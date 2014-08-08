class Tyrant
  module Time
    HOUR = 3600
    MINUTE = 60
    DAY = HOUR * 24

    def self.format_time_days(seconds)
      return '-' + format_time_days(-seconds) if seconds < 0
      days = seconds / DAY
      seconds %= DAY

      return "#{days}d " + format_time(seconds)
    end

    def self.format_time(seconds)
      return '-' + format_time(-seconds) if seconds < 0

      hours = seconds / HOUR
      seconds %= HOUR
      minutes = seconds / MINUTE
      seconds %= MINUTE
      return "%02d:%02d:%02d" % [hours, minutes, seconds]
    end
  end
end
