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
set :environment, :production

class MultiIO
  def initialize(*targets)
     @targets = targets
  end

  def write(*args)
    @targets.each {|t| t.write(*args)}
  end

  def close
    @targets.each(&:close)
  end
end

set :logging, nil
$logger = Logger.new MultiIO.new(STDOUT, File.open('logs/osusume.log', 'a'))
$logger.level = Logger::INFO
$logger.datetime_format = '%a %d-%m-%Y %H%M '
set :logger, $logger

dsn = ENV["HEROKU_POSTGRESQL_TEAL_URL"]
DataMapper::setup(:default, dsn)
class Osusume
    include DataMapper::Resource
    property :id, Serial
    property :name, String, :unique => true
    property :regexp, String, :length => 256
    property :content, String, :length => 256
    property :created_by, String, :length => 256
    property :enable, Boolean, :default => true
end
class Bot
    include DataMapper::Resource
    property :id, Serial
    property :name, String, :unique => true
	property :endpoint, String, :length => 256
end
DataMapper.finalize
Osusume.auto_upgrade!
Bot.auto_upgrade!

OSUSUME_ROOMS = %w[computer_science vim mcujm bottest3 imascg momonga]
LINGR_IP = '219.94.235.225'
BOT_VERIFIER = Digest::SHA1.hexdigest("osusume#{ENV["OSUSUME_BOT_SECRET"]}")
OSUSUME_NOTIFY_ROOM = 'computer_science'

def urlencode(x)
  ERB::Util.url_encode x
end

def bot_relay(bot, message)
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
  $logger.info("Relay endpoint: #{bot}")
  endpoint = URI.parse(uri)
  status = { "events" => [{ "message" => message }] }
  req = Net::HTTP::Post.new(endpoint.path, initheader = {'Content-Type' =>'application/json', 'Host' => endpoint.host, 'HTTP_X_REAL_IP' => LINGR_IP})
  req.body = status.to_json
  req.content_type = 'application/json'
  http = Net::HTTP.new(endpoint.host, endpoint.port)
  http.start do |h|
    return h.request(req).body
  end
  return ''
end

module Web
  module_function
  def osusume(message, from_web_p)
    return if message['room'] && !OSUSUME_ROOMS.include?(message['room'])
    case message['text']
    when /^!osusume\s+(\S+)\s+(\S+)(?:\s+(.+))?$/m
      m = Regexp.last_match
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
    when /^!osusume\s+(\S+)$/
      m = Regexp.last_match
      name = m[1]
      item = Osusume.first({:name => name, :enable => true})
      if item
        "Name: #{item[:name]}\n" +
        "Regexp: /#{item[:regexp]}/\n" +
        "Content: #{item[:content]}\n"
      else
        "Not found '#{name}'\n"
      end
    when /^!osusume\?\s+(.+)$/m
      m = Regexp.last_match
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
    when /^!osusume!\s+(\S+)$/
      m = Regexp.last_match
      name = m[1]
      item = Osusume.first({:name => name})
      if item
        if from_web_p
          item.update({:enable => false}) && "Deleted '#{name}'\n"
        else
          item.destroy && "Deleted '#{name}'\n"
        end
      else
        "Not found '#{name}'\n"
      end
    when /^!osusume$/
      Osusume.all(:enable => true).map {|x|
        "'#{x[:name]}' /#{x[:regexp]}/"
      }.join "\n"
    else
      t = message['text']
      Osusume.all(:enable => true).map {|x|
        begin
          m = Regexp.new(x[:regexp], Regexp::MULTILINE | Regexp::EXTENDED).match(t)
        rescue => e
          next
        end
        next if !m
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
          content = bots.map {|x| "#{x} response:\n#{bot_relay(x, relay)}"}.join("\n")
        end
        content.gsub! /\$bot\(\s*("[^"]*"|\[(?:\s*(?:"[^"]*")\s*,)*(?:"[^"]*")\])\s*\)/ do |x| # x isn't used...!
          bots = JSON.parse("[#{$1}]").flatten
          content = bots.map {|x| "#{x} response:\n#{bot_relay(x, message)}"}.join("\n")
        end
        content
      }.compact.sample.to_s
    end
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
  open('logs/osusume.log').read
end

get '/ping' do
  content_type "text/plain"
  "OK"
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
    return 'no change' if item[:enable] == enable
    item.update({enable: enable})
    text = "'#{params[:name]}' がたぶんWebから#{enable ? "有効": "無効"}に変更されました"
    open "http://lingr.com/api/room/say?room=#{OSUSUME_NOTIFY_ROOM}&bot=osusume&text=#{urlencode(text)}&bot_verifier=#{BOT_VERIFIER}"
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
