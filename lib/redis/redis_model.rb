module RedisModel
  extend ActiveSupport::Concern

  attr_accessor :attributes

  def initialize(attributes)
    @attributes = attributes
  end

  def [](attribute_key)
    attributes[attribute_key]
  end

  def []=(attribute_key, attribute_value)
    attributes[attribute_key]= attribute_value
  end

  def key
    @key ||= begin
               @id ||= connection.incr("#{scope_name}.id")
               "#{scope_name}/#{@id}"
             end
  end

  def save
    connection.hmset(key, attributes.to_a.flatten)
    connection.sadd(scope_name, key)
  end

  def update_attribute(attribute_key, attribute_value)
    @attributes[attribute_key] = attribute_value
    connection.hset(key, attribute_key, attribute_value)
  end

  def scope_name
    self.class.scope_name
  end

  def ==(another)
    key == (another.key)
  end

  def eql?(another)
    self == another
  end

  # A naive implementation of attribute accessor methods, should define the
  # accessor methods for each key when they be accessed.
  def method_missing(method, *args, &block)
    match = method.to_s.match(/^(\w+)=$/)
    attr_key = match ? match[1].to_sym : method

    if @attributes.has_key?(attr_key)
      if match
        self[attr_key]= args.first
      else
        self[attr_key]
      end
    else
      super
    end
  end

  def connection
    self.class.connection
  end

  module ClassMethods
    def all
      connection.smembers(scope_name).map do |key|
        find(key)
      end
    end

    def find(key)
      instance = new(connection.hgetall(key))
      instance.instance_variable_set(:@key, key)
      instance
    end

    def create(attributes)
      instance = new(attributes)
      instance.save
      instance
    end

    def scope_name
      name.tableize
    end

    def connection
      @connection ||= begin
                        connection = Redis::Namespace.new(ENV['ECHIDNA_REDIS_NAMESPACE'], redis: SymbolizedRedis.new(host: ENV['ECHIDNA_REDIS_HOST'], port: ENV['ECHIDNA_REDIS_PORT'], driver: :hiredis))

                        $logger.notice("RedisModel connect to redis: #{ENV['ECHIDNA_REDIS_HOST']}:#{ENV['ECHIDNA_REDIS_PORT']}/#{ENV['ECHIDNA_REDIS_NAMESPACE']}")
                        connection
                      end
    end
  end
end
