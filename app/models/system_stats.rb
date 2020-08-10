class SystemStats
  def self.report_gauge(stat:, value:)
    Rails.logger.info "stat: #{stat}, value: #{value}"
  end
end
