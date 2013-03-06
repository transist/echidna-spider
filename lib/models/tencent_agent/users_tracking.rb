class TencentAgent
  module UsersTracking
    extend ActiveSupport::Concern

    LIST_NAME = 'userlist'

    def user_list
      if @list.nil?
        result = post('api/list/get_list')
        @list = handle_result(result, "Failed to get list") do |r|
          r['data']['info'].find{|el| el['name'] == LIST_NAME }
        end
      end

      if @list.nil?
        result = post('api/list/create', format: 'json', name: LIST_NAME, description: LIST_NAME, tag: 'echidna', access: '1')
        @list = handle_result(result, "Failed to create list")
      end

      @list
    end

    def add_user_to_list username
      result = post('api/list/add_to_list', format: 'json',  names: username, listid: user_list['listid'])
      handle_result(result, 'Failed to add user to list')
    end

    def handle_result(result, errmsg, &block)
      ret = nil
      if result["errcode"].to_s == "0"
        if block_given?
          ret = block.call(result)
        else
          ret = result['data']
        end
      else
        $logger.err log("#{errmsg}, errcode: #{result["errcode"]}, msg: #{result["msg"]}")
        ret = {}
      end
      ret
    end
  end
end
