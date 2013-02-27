module RedisModel
  extend ActiveSupport::Concern

  attr_accessor :attributes

  def initialize(attributes)
    @attributes = attributes
  end

  def key
    @key ||= begin
               @id ||= $redis.incr("#{scope_name}.id")
               "#{scope_name}/#{@id}"
             end
  end

  def save
    $redis.hmset(key, attributes.to_a.flatten)
    $redis.sadd(scope_name, key)
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

  module ClassMethods
    def all
      $redis.smembers(scope_name).map do |key|
        find(key)
      end
    end

    def find(key)
      instance = new($redis.hgetall(key))
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
  end
end
