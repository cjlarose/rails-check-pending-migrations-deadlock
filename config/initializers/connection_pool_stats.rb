module DbConnectionPoolStatsReporter
  def self.report(pool)
    pool_stats = pool.stat
    [:size, :connections, :busy, :dead, :idle, :waiting, :checkout_timeout].each do |stat|
      SystemStats.report_gauge stat: "db_connection_pool.#{stat}",
                               value: pool_stats[stat]
    end
  end
end

ActiveSupport.on_load(:active_record) do
  ActiveRecord::ConnectionAdapters::Mysql2Adapter.set_callback :checkout, :after do |conn|
    DbConnectionPoolStatsReporter.report conn.pool
  end

  ActiveRecord::ConnectionAdapters::Mysql2Adapter.set_callback :checkin, :after do |conn|
    DbConnectionPoolStatsReporter.report conn.pool
  end
end

Thread.new do
  binding.remote_pry
end
