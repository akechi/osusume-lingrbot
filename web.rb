# -*- coding: utf-8 -*-
require 'bundler'
require 'open-uri'
require 'digest/sha1'
require 'json'
require 'erb'

Dir.chdir File.dirname(__FILE__)
Bundler.require
set :environment, :production

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/osusume.db")
class Osusume
    include DataMapper::Resource
    property :id, Serial
    property :name, String, :unique => true
    property :regexp, String, :length => 256
    property :content, String, :length => 256
    property :created_by, String, :length => 256
    property :deleted, Boolean, :default => false
end
DataMapper.finalize
Osusume.auto_upgrade!

def urlencode(x)
  ERB::Util.url_encode x
end

OSUSUME_ROOMS = %w[computer_science vim bottest3]
@lingr_ip = nil
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
    if item.update({:regexp => regexp, :content => content, :created_by => created_by, :deleted => false})
      "Updated '#{name}'\n"
    else
      ''
    end
  when /^!osusume\s+(\S+)$/
    m = Regexp.last_match
    name = m[1]
    item = Osusume.first({:name => name, :deleted => false})
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
    messages = Osusume.all(:deleted => false).select {|x|
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
        item.update({:deleted => true}) && "Deleted '#{name}'\n"
      else
        item.destroy && "Deleted '#{name}'\n"
      end
    else
      "Not found '#{name}'\n"
    end
  when /^!osusume$/
    Osusume.all(:deleted => false).map {|x|
      "'#{x[:name]}' /#{x[:regexp]}/"
    }.join "\n"
  else
    Osusume.all(:deleted => false).map {|x|
      begin
        m = Regexp.new(x[:regexp], Regexp::MULTILINE | Regexp::EXTENDED).match(message['text'])
      rescue
        next
      end
      next if !m
      content = x[:content]
      (0...m.size).each do |x|
        content.gsub!("$!#{x}", URI.escape(m[x]))
        content.gsub!("$#{x}", m[x])
      end
      content.gsub! /\$m\[["']([^"']+)["']\]/ do |x| # x isn't used...!
        message[$1]
      end
      content
    }.compact.sample.to_s
  end
end

get '/application.css' do
  sass :application
end

get '/application.js' do
  coffee :application
end

get '/' do
  @osusumes = Osusume.all
  slim :index
end

BOT_VERIFIER = Digest::SHA1.hexdigest("osusume" + ENV["OSUSUME_BOT_SECRET"])
OSUSUME_NOTIFY_ROOM = 'computer_science'

post '/delete' do
  content_type :json
  item = Osusume.first({:name => params[:name], :deleted => false})
  if item != nil
    item.update({:deleted => true})
    open "http://lingr.com/api/room/say?room=#{ENV["OSUSUME_NOTIFY_ROOM"]}&bot=osusume&text=#{urlencode("'#{params[:name]}' がたぶんWebから削除されました")}&bot_verifier=#{BOT_VERIFIER}"
    '{"status": "OK"}'
  else
    status 404
    "the osusume isn't on my DB"
  end
end

post '/api' do
  content_type :json
  result = osusume({"text"=> params[:text]}, true)
  open "http://lingr.com/api/room/say?room=computer_science&bot=osusume&text=#{urlencode("#{params[:text].inspect} => #{result.inspect} from #{request.env['HTTP_X_REAL_IP']}")}&bot_verifier=#{BOT_VERIFIER}"
  {:osusume => "#{result}"}.to_json
end

post '/lingr' do
  @lingr_ip = request.env['REMOTE_ADDR']
  json = JSON.parse(request.body.string)
  json["events"].
    map {|e| e['message'] }.
    compact.
    map {|x| "#{osusume(x, false)}" }.
    join.
    rstrip[0..999]
end
