require 'spec_helper'

describe 'i18n' do

  before(:each) { set_api_key_header }

  it 'should respect the Accept-Language header' do
    put '/api/v1/comments/does_not_exist/votes', {}, {'HTTP_ACCEPT_LANGUAGE' => 'x-test'}
    last_response.status.should == 400
    parse(last_response.body).first.should == '##x-test## requested object not found'
  end
end
