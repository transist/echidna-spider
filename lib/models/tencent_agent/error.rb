class TencentAgent
  class Error < StandardError
    def initialize(message = nil, response_body = nil)
      @response_body = response_body
      super(message)
    end

    def to_s
      if @response_body
        "#{super}: #{@response_body.inspect}"
      else
        super
      end
    end
  end
end
