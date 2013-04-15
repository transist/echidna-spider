class TencentAgent
  class Error < StandardError
    def initialize(message = nil, response_body = nil)
      @response_body = response_body
      super(message)
    end

    def to_s
      "#{super}: #{@response_body.inspect}"
    end
  end
end
