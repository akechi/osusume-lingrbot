ENV['RACK_ENV'] = 'test'

require './web'
require 'rspec'
require 'rack/test'
require 'json'

describe 'The Osusume' do
  before(:all) do
    Osusume.all.destroy
  end

  describe 'finder' do
    context 'not found' do
      before(:all) do
        text = '!osusume shimau'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        @m = Web.get_regexp(:osusume_info).match(text)
      end
      subject { Web.osusume_info(@message, @m) }
      it { should be_a_kind_of(String) }
      it { should == "Not found 'shimau'\n" }
    end
  end

  describe 'update' do
    context 'new' do
      before(:all) do
        text = '!osusume shimau (?<!でし)(?<!てし)(?<!ち)(?<!か)(?<!のた)まう([っ〜ー]*([。．.！!]|$)|[っ〜ー]{2,}) http://shimau.jpg'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        @m = Web.get_regexp(:osusume_update).match(text)
      end
      subject { Web.osusume_update(@message, @m) }
      it { should be_a_kind_of(String) }
      it { should == "Updated 'shimau'\n" }
    end

    context 'modify' do
      before(:all) do
        text = '!osusume shimau (?<!でし)(?<!てし)(?<!ち)(?<!か)(?<!のた)まう([っ〜ー]*([。．.！!]|$)|[っ〜ー]{2,})'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        @m = Web.get_regexp(:osusume_update).match(text)
      end
      subject { Web.osusume_update(@message, @m) }
      it { should be_a_kind_of(String) }
      it { should == "Updated 'shimau'\n" }
    end

    context 'found' do
      before(:all) do
        text = '!osusume shimau'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        @m = Web.get_regexp(:osusume_info).match(text)
      end
      subject { Web.osusume_info(@message, @m) }
      it { should be_a_kind_of(String) }
      it { should == "Name: shimau\nRegexp: /(?<!でし)(?<!てし)(?<!ち)(?<!か)(?<!のた)まう([っ〜ー]*([。．.！!]|$)|[っ〜ー]{2,})/\nContent: http://shimau.jpg\nFull definition:\n!osusume shimau (?<!でし)(?<!てし)(?<!ち)(?<!か)(?<!のた)まう([っ〜ー]*([。．.！!]|$)|[っ〜ー]{2,}) http://shimau.jpg" }
    end
  end

  describe 'match' do
    context 'no' do
      before(:all) do
        text = '!osusume? あももももももっもっもおも'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        @m = Web.get_regexp(:osusume_match).match(text)
      end
      subject { Web.osusume_match(@message, @m) }
      it { should be_a_kind_of(String) }
      it { should == "No matched" }
    end

    context 'success' do
      before(:all) do
        text = '!osusume? まう'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        @m = Web.get_regexp(:osusume_match).match(text)
      end
      subject { Web.osusume_match(@message, @m) }
      it { should be_a_kind_of(String) }
      it { should == "Matched with 'shimau'" }
    end

    context 'new another one' do
      before(:all) do
        text = '!osusume かしまし娘 かしましまう http://oh.jpg'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        @m = Web.get_regexp(:osusume_update).match(text)
      end
      subject { Web.osusume_update(@message, @m) }
      it { should be_a_kind_of(String) }
      it { should == "Updated 'かしまし娘'\n" }
    end

    context 'no' do
      before(:all) do
        text = '!osusume? かしましまう'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        @m = Web.get_regexp(:osusume_match).match(text)
      end
      subject { Web.osusume_match(@message, @m) }
      it { should be_a_kind_of(String) }
      it { should == "Matched with 'shimau'\nMatched with 'かしまし娘'" }
    end
  end

  describe 'delete' do
    context 'success' do
      before(:all) do
        text = '!osusume! かしまし娘'
        message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        m = Web.get_regexp(:osusume_cancel).match(text)
        @result = Web.osusume_cancel(message, m, false)
      end
      subject { @result }
      it { should be_a_kind_of(String) }
      it { should == "Deleted 'かしまし娘'\n" }
    end

    context 'not deleted' do
      before(:all) do
        text = '!osusume! かしまし娘'
        message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        m = Web.get_regexp(:osusume_cancel).match(text)
        @result = Web.osusume_cancel(message, m, false)
      end
      subject { @result }
      it { should be_a_kind_of(String) }
      it { should == "Not found 'かしまし娘'\n" }
    end
  end

  describe 'last' do
    context 'not found' do
      before(:all) do
        text = '!osusume!?'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        @m = Web.get_regexp(:osusume_last).match(text)
      end
      subject { Web.osusume_last(@message, @m) }
      it { should be_a_kind_of(String) }
      it { should == "Last osusume is ''" }
    end

    context 'match' do
      before(:all) do
        text = 'よろしくおねがいしまう'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
      end
      subject { Web.osusume_the_greatest_hit(@message) }
      it { should be_a_kind_of(String) }
      it { should == "http://shimau.jpg" }
    end

    context 'found' do
      before(:all) do
        text = '!osusume!?'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        @m = Web.get_regexp(:osusume_last).match(text)
      end
      subject { Web.osusume_last(@message, @m) }
      it { should be_a_kind_of(String) }
      it { should == "Last osusume is 'shimau'" }
    end
  end

  describe 'disable last and enable on room' do
    context 'disalbe last on the room' do
      before(:all) do
        text = '!osusume!!'
        message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        m = Web.get_regexp(:osusume_disable_last_on_the_room).match(text)
        @result = Web.osusume_disable_last_on_the_room(message, m)
      end
      subject { @result }
      it { should be_a_kind_of(String) }
      it { should == "Disabled 'shimau' on 'imascg'\n" }
    end

    context 'match' do
      before(:all) do
        text = 'よろしくおねがいしまう'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
      end
      subject { Web.osusume_the_greatest_hit(@message) }
      it { should be_a_kind_of(String) }
      it { should == "" }
    end

    context 'enalbe on the room' do
      before(:all) do
        text = '!osusume!!! shimau'
        message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
        m = Web.get_regexp(:osusume_enable_on_the_room).match(text)
        @result = Web.osusume_enable_on_the_room(message, m)
      end
      subject { @result }
      it { should be_a_kind_of(String) }
      it { should == "Enabled 'shimau' on 'imascg'\n" }
    end

    context 'not match' do
      before(:all) do
        text = 'よろしくおねがいしまう'
        @message = { "text" => text, "room" => "imascg", "nickname" => "joe" }
      end
      subject { Web.osusume_the_greatest_hit(@message) }
      it { should be_a_kind_of(String) }
      it { should == "http://shimau.jpg" }
    end
  end
end

describe 'The Osusume via Sinatra' do
  include Rack::Test::Methods

  def app
    Sinatra::Application
  end

  before(:all) do
    Osusume.all.destroy
    Web.osusume_clear_last
  end

  context 'not fuond' do
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

  context 'create' do
    it do
      text = '!osusume かしまし娘 かしましまう http://oh.jpg'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Updated 'かしまし娘'"
    end
  end

  context 'match' do
    it do
      text = '!osusume? かしましまう'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Matched with 'shimau'\nMatched with 'かしまし娘'"
    end
  end

  context 'delete' do
    it do
      text = '!osusume! かしまし娘'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Deleted 'かしまし娘'"
    end
  end

  context 'not deleted' do
    it do
      text = '!osusume! かしまし娘'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Not found 'かしまし娘'"
    end
  end

  context 'last not found' do
    it do
      text = '!osusume!?'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Last osusume is ''"
    end
  end

  context 'message match test' do
    it do
      text = 'よろしくおねがいしまう'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "http://shimau.jpg"
    end
  end

  context 'last' do
    it do
      text = '!osusume!?'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Last osusume is 'shimau'"
    end
  end

  context 'disable last on the room' do
    it do
      text = '!osusume!!'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Disabled 'shimau' on 'imascg'"
    end
  end

  context 'message not match' do
    it do
      text = 'よろしくおねがいしまう'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == ""
    end
  end

  context 'disable last on the room' do
    it do
      text = '!osusume!!! shimau'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "Enabled 'shimau' on 'imascg'"
    end
  end

  context 'message match' do
    it do
      text = 'よろしくおねがいしまう'
      body = { "events" => [ { "message" => { "text" => text, "room" => "imascg", "nickname" => "joe" } } ] }
      post '/lingr', body.to_json.to_s
      last_response.should be_ok
      last_response.body.should == "http://shimau.jpg"
    end
  end
end

