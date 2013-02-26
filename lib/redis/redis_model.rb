module RedisModel
  extend ActiveSupport::Concern

  attr_accessor :attributes

  def initialize(attributes)
    @attributes = attributes
  end

  def key
    @id ||= $redis.incr("#{scope_name}.id")
    "#{scope_name}/#{@id}"
  end

  def save
    $redis.hmset(key, attributes.to_a.flatten)
    $redis.sadd(scope_name, key)
  end

  def scope_name
    self.class.scope_name
  end

  module ClassMethods
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
