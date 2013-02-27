$redis = EventMachine::Synchrony::ConnectionPool.new(size: 2) do
  Redis::Namespace.new(
    ENV['ECHIDNA_REDIS_NAMESPACE'],
    redis: SymbolizedRedis.new(
      host: ENV['ECHIDNA_REDIS_HOST'], port: ENV['ECHIDNA_REDIS_PORT'], driver: :synchrony
    )
  )
end