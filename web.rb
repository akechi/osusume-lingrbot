# -*- coding: utf-8 -*-
require 'bundler'
require 'open-uri'
require 'nokogiri'
require 'digest/sha1'
require 'net/http'
require 'json'
require 'erb'
require 'logger'

Dir.chdir File.dirname(__FILE__)
Bundler.require

class MultiIO
  def initialize(*targets)
     @targets = targets
  end

  def <<(*args)
    @targets.each {|t| t.<<(*args); t.flush }
  end

  def write(*args)
    @targets.each {|t| t.write(*args); t.flush }
  end

  def puts(*args)
    @targets.each {|t| t.write(*args); t.write("\n"); t.flush }
  end

  def close
    @targets.each(&:close)
  end

  def flush
    @targets.each(&:flush)
  end
end

$filelog = File.new("logs/osusume.log", "a+")
$stdout = MultiIO.new($stdout, $filelog)
$stderr = MultiIO.new($stderr, $filelog)
$logger = Logger.new($filelog)
set :logger, $logger
$web_uri = ENV['OSUSUME_WEB_URI'] || "http://osusume.herokuapp.com/"

class Osusume
    include DataMapper::Resource
    property :id, Serial
    property :name, String, :unique => true
    property :regexp, String, :length => 256
    property :content, String, :length => 256
    property :created_by, String, :length => 256
    property :enable, Boolean, :default => true
    property :except, String, :length => 256
end
class Bot
    include DataMapper::Resource
    property :id, Serial
    property :name, String, :unique => true
	property :endpoint, String, :length => 256
end
DataMapper.finalize

configure :production do
  dsn = ENV["HEROKU_POSTGRESQL_TEAL_URL"]
  DataMapper::setup(:default, dsn)
  Osusume.auto_upgrade!
  Bot.auto_upgrade!
  LINGR_IP = '219.94.235.225'
end

configure :test, :development do
  FileUtils.rm_rf('/tmp/osusume')
  DataMapper.setup(:default, "yaml:///tmp/osusume")
  Osusume.auto_upgrade!
  Bot.auto_upgrade!
  LINGR_IP = '127.0.0.1'
end

OSUSUME_ROOMS = %w[computer_science vim mcujm bottest3 imascg momonga mtroom sugoi benri_m pv0512 SandBox monetize cpp sinatra_sapporo js]
BOT_VERIFIER = Digest::SHA1.hexdigest("osusume#{ENV["OSUSUME_BOT_SECRET"]}")
OSUSUME_NOTIFY_ROOM = 'computer_science'

def urlencode(x)
  ERB::Util.url_encode x
end

def notify(text)
  open "http://lingr.com/api/room/say?room=#{OSUSUME_NOTIFY_ROOM}&bot=osusume&text=#{urlencode(text)}&bot_verifier=#{BOT_VERIFIER}"
end

def bot_relay(bot, message)
  return 'osusumeなら俺の隣で寝てるよ？' if bot == 'osusume'
  found = Bot.first({:name => bot})
  uri = ''
  if found
    uri = found[:endpoint]
  else
    $logger.info("Fetching bot endpoint: #{bot}")
    f = open("http://lingr.com/bot/#{bot}").read
    doc = Nokogiri::HTML.parse(f)
    doc.css('#property .left').each do |node|
      if node.text =~ /Endpoint:/
        uri = node.next.next.text.strip
        return '' if uri == ''
        Bot.create({:name => bot, :endpoint => uri})
      end
    end
  end
  return '' if uri == ""
  endpoint = URI.parse(uri)
  $logger.info("Relay endpoint: #{endpoint}")
  status = { "events" => [{ "message" => message }] }
  begin
    req = Net::HTTP::Post.new(endpoint.path.empty? ? "/" : endpoint.path, initheader = {'Content-Type' =>'application/json', 'Host' => endpoint.host, 'HTTP_X_REAL_IP' => LINGR_IP})
    req.body = status.to_json
    req.content_type = 'application/json'
    http = Net::HTTP.new(endpoint.host, endpoint.port)
    http.start do |h|
      res = h.request(req)
      if res.code == '200'
        return res.body
      else
        log_uri = "#{$web_uri}log"
        return "Response code #{res.code} returned.\n#{log_uri}"
      end
    end
  rescue Exception => e
    $logger.info e.message
    $logger.info e.backtrace.inspect
    log_uri = "#{$web_uri}log"
    return "An error occurd when bot relaying.\n#{log_uri}"
  end
  return ''
end

module Web
  module_function

  @@last_osusume = ""

  def osusume_disable(message, m)
    name = m[1]
    item = Osusume.first({:name => name})
    if item
      item.update({:enable => false}) && "Deleted '#{name}'\n"
    else
      "Not found '#{name}'\n"
    end
  end

  def osusume_destroy(message, m)
    name = m[1]
    item = Osusume.first({:name => name})
    if item
      item.destroy && "Deleted '#{name}'\n"
    else
      "Not found '#{name}'\n"
    end
  end

  @@osusume_callbacks = [
    [/^!osusume\s+(\S+)\s+(\S+)(?:\s+(.+))?$/m, :osusume_update, proc do |message, m, dummy = true|
      name = m[1]
      regexp = m[2]
      content = m[3]
      item = Osusume.first_or_create({:name => name})
      content = item[:content] unless content
      created_by = item[:created_by] || message['nickname']
      if item.update({:regexp => regexp, :content => content, :created_by => created_by, :enable => true})
        "Updated '#{name}'\n"
      else
        ''
      end
    end],

    [/^!osusume\s+(\S+)$/, :osusume_info, proc do |message, m, dummy = true|
      name = m[1]
      item = Osusume.first({:name => name, :enable => true})
      if item
        "Name: #{item[:name]}\n" +
        "Regexp: /#{item[:regexp]}/\n" +
        "Content: #{item[:content]}\n"
      else
        "Not found '#{name}'\n"
      end
    end],

    [/^!osusume\?\s+(.+)$/m, :osusume_match, proc do |message, m, dummy = true|
      text = m[1]
      messages = Osusume.all(:enable => true).select {|x|
        begin
          Regexp.new(x[:regexp], Regexp::MULTILINE | Regexp::EXTENDED).match(text)
        rescue
          false
        end
      }.map {|x|
        "Matched with '#{x[:name]}'"
      }
      messages.empty? ? 'No matched' : messages.join("\n")
    end],

    [/^!osusume!\?$/, :osusume_last, proc do |message, m, dummy = true|
      "Last osusume is '#{@@last_osusume}'"
    end],

    [/^!osusume!!!\s+(\S+)$/, :osusume_enable_on_the_room, proc do |message, m, dummy = true|
      name = m[1]
      item = Osusume.first({:name => name})
      if item
        except = (item[:except] || "").split(/,/).map{|x| x.strip}
        except.delete(message['room'])
        item.update({:except => except.compact.join(",")}) && "Enabled '#{name}' on '#{message['room']}'\n"
      else
        ""
      end
    end],

    [/^!osusume!!$/, :osusume_disable_last_on_the_room, proc do |message, m, dummy = true|
      unless @@last_osusume.nil?
        item = Osusume.first({:name => @@last_osusume})
        if item
          except = (item[:except] || "").split(/,/).map{|x| x.strip} << message['room']
          item.update({:except => except.compact.join(",")}) && "Disabled '#{@@last_osusume}' on '#{message['room']}'\n"
        else
          ""
        end
      end
    end],

    [/^!osusume!\s+(\S+)$/, :osusume_cancel, proc do |message, m, is_from_web|
      if is_from_web
        osusume_disable(message, m)
      else
        osusume_destroy(message, m)
      end
    end],
  ].each do |(regexp, method_name, proc)|
    define_method(method_name.to_sym, proc)
    module_function method_name.to_sym
  end

  def get_regexp(method_name)
    result = @@osusume_callbacks.select { |item| item[1] == method_name.to_sym }
    result.empty? ? nil : result.first[0]
  end

  def osusume_clear_last
    @@last_osusume = ""
  end

  def osusume_the_greatest_hit(message)
    t = message['text']
    Osusume.all(:enable => true).map {|x|
      except = (x[:except] || "").split(/,/).compact.map{|x| x.strip}
      unless except.empty?
        next if except.include?(message['room'])
      end

      begin
        m = Regexp.new(x[:regexp], Regexp::MULTILINE | Regexp::EXTENDED).match(t)
      rescue => e
        next
      end
      next if !m
      @@last_osusume = x[:name]
      content = x[:content]
      (0...m.size).each do |x|
        content.gsub!("$!#{x}", urlencode(m[x]))
        content.gsub!("$#{x}", m[x])
      end
      content.gsub! /\$m\[("[^"]*")\]/ do |x| # x isn't used...!
        key = JSON.parse("[#{$1}]")[0]
        message[key]
      end
      content.gsub! /\$bot\(\s*("[^"]*"|\[(?:\s*(?:"[^"]*")\s*,)*(?:"[^"]*")\])\s*,\s*("[^"]*")\)/ do |x| # x isn't used...!
        bots = JSON.parse("[#{$1}]").flatten
        text = JSON.parse("[#{$2}]")[0]
        relay = message.dup
        relay["text"] = text
        content = bots.map { |b|
          response = bot_relay(b, relay)
          response.split.empty? ? "" : "#{b} response:\n#{response}"
        }.select{|r| not r.empty?}.join("\n")
      end
      content.gsub! /\$bot\(\s*("[^"]*"|\[(?:\s*(?:"[^"]*")\s*,)*(?:"[^"]*")\])\s*\)/ do |x| # x isn't used...!
        bots = JSON.parse("[#{$1}]").flatten
        content = bots.map { |b|
          response = bot_relay(b, message)
          response.split.empty? ? "" : "#{b} response:\n#{response}"
        }.select{|r| not r.empty?}.join("\n")
      end
      content
    }.compact.sample.to_s
  end

  def osusume(message, is_from_web)
    return if message['room'] && !OSUSUME_ROOMS.include?(message['room'])
    result = @@osusume_callbacks.each { |(regexp, method_name, proc)|
      m = regexp.match(message['text'])
      if not m.nil?
        break method_name.to_proc.(self, message, m, is_from_web)
      end
    }
    result.is_a?(Array) ? osusume_the_greatest_hit(message) : result
  end
end

get '/application.css' do
  sass :application
end

get '/application.js' do
  coffee :application
end

get '/relay' do
  content_type :json
  Bot.all.to_json
end

get '/log' do
  content_type 'text/plain'
  open("logs/osusume.log").read.lines.reverse[0...200].reverse
end

get '/ping' do
  content_type "text/plain"
  "OK"
end

get '/simple' do
  @osusumes = Osusume.all
  slim :simple
end

get '/' do
  @osusumes = Osusume.all.each {|x|
    x[:content] = x[:content].gsub(/</, '&lt;').gsub(/>/, '&gt;') if x[:content]
  }
  slim :index
end

post '/manage' do
  content_type :json
  item = Osusume.first({name: params[:name]})
  if item
    enable = params[:enable] == 'true'
    return "no change. item status:#{item[:enable]}" if item[:enable] == enable
    item.update({enable: enable})
    text = "'#{params[:name]}' がたぶんWebから#{enable ? "有効": "無効"}に変更されました"
    notify text
    '{"status": "OK"}'
  else
    status 404
    "the osusume isn't on my DB"
  end
end

post '/api' do
  content_type :json
  result = Web.osusume({"text"=> params[:text]}, true)
  open "http://lingr.com/api/room/say?room=computer_science&bot=osusume&text=#{urlencode("#{params[:text].inspect} => #{result.inspect} from #{request.env['HTTP_X_REAL_IP']}")}&bot_verifier=#{BOT_VERIFIER}"
  {osusume: "#{result}"}.to_json
end

post '/lingr' do
  return "" unless request.ip == LINGR_IP
  json = JSON.parse(request.body.string)
  json["events"].
    map {|e| e['message'] }.
    compact.
    map {|x| "#{Web.osusume(x, false)}" }.
    join.
    rstrip[0..999]
end

notify "osusume-san reloaded"
