class SymbolizedRedis < Redis
  def _hashify
    lambda { |array|
      hash = Hash.new
      array.each_slice(2) do |field, value|
        hash[field.to_sym] = value
      end
      hash
    }
  end
end
