ENV['RACK_ENV'] = 'test'

require './web'
require 'rspec'
require 'rack/test'
require 'json'

describe 'The Osusume' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  context 'not find' do
    it do
      text = '!osusume shimau'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Not found 'shimau'"
    end
  end

  context 'create' do
    it do
      text = '!osusume shimau (?<!でし)(?<!てし)(?<!ち)(?<!か)(?<!のた)まう([っ〜ー]*([。．.！!]|$)|[っ〜ー]{2,}) http://shimau.jpg'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Updated 'shimau'"
    end
  end

  context 'update' do
    it do
      text = '!osusume shimau (?<!でし)(?<!てし)(?<!ち)(?<!か)(?<!のた)まう([っ〜ー]*([。．.！!]|$)|[っ〜ー]{2,})'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Updated 'shimau'"
    end
  end

  context 'info' do
    it do
      text = '!osusume shimau'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Name: shimau\nRegexp: /(?<!でし)(?<!てし)(?<!ち)(?<!か)(?<!のた)まう([っ〜ー]*([。．.！!]|$)|[っ〜ー]{2,})/\nContent: http://shimau.jpg"
    end
  end

  context 'match' do
    it do
      text = '!osusume? よろしくおねがいしまう'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Matched with 'shimau'"
    end
  end

  context 'not match' do
    it do
      text = '!osusume? 食べてしまう'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "No matched"
    end
  end
end

