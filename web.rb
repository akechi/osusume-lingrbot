# -*- coding: utf-8 -*-
require 'bundler'
require 'open-uri'
require 'digest/sha1'

Dir.chdir File.dirname(__FILE__)
Bundler.require
set :environment, :production

DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/osusume.db")
class Osusume
    include DataMapper::Resource
    property :id, Serial
    property :name, String, :unique => true
    property :content, String, :length => 256
    property :regexp, String, :length => 256
end
DataMapper.finalize
Osusume.auto_upgrade!

def osusume(message)
  text = message['text']
  ret = ''
  case text
  when /^!osusume\s+(\S+)\s+(\S+)\s+(.+)$/m
    m = Regexp.last_match
    name = m[1]
    regexp = m[2]
    content = m[3]
    item = Osusume.first_or_create({:name => name})
    if item.update({:regexp => regexp, :content => content})
      ret += "Updated '#{name}'\n"
    end
  when /^!osusume\s+(\S+)$/
    m = Regexp.last_match
    name = m[1]
    item = Osusume.first({:name => name})
    if item != nil
      ret += "Name: #{item[:name]}\n"
      ret += "Regexp: /#{item[:regexp]}/\n"
      ret += "Content: #{item[:content]}\n"
    else
      ret += "Not found '#{name}'\n"
    end
  when /^!osusume\?\s+(.+)$/m
    m = Regexp.last_match
    text = m[1]
    matched = false
    Osusume.all.each do |x|
      if Regexp.new(x[:regexp], Regexp::MULTILINE | Regexp::EXTENDED).match(text)
        ret += "Matched with '#{x[:name]}'\n"
        matched = true
      end
    end
    ret += 'No matched' unless matched
  when /^!osusume!\s+(\S+)$/
    m = Regexp.last_match
    name = m[1]
    item = Osusume.first({:name => name})
    if item != nil
      item.destroy
      ret += "Deleted '#{name}'\n"
    else
      ret += "Not found '#{name}'\n"
    end
  when /^!osusume$/
    ret += Osusume.all.map {|x|
      "'#{x[:name]}' /#{x[:regexp]}/"
    }.join "\n"
  else
    res = []
    Osusume.all.each do |x|
      m = Regexp.new(x[:regexp], Regexp::MULTILINE | Regexp::EXTENDED).match(text)
      next if !m
      content = x[:content]
      (0...m.size).each do |x|
        content.gsub!("$!#{x}", URI.escape(m[x]))
        content.gsub!("$#{x}", m[x])
      end
      content.gsub! /\$m\[["']([^"']+)["']\]/ do |x|
        message[$1]
      end
      res << content
    end
    ret = "#{res.sample}"
  end
  ret
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

post '/delete' do
  content_type :json
  bot_verifier = Digest::SHA1.hexdigest("osusume" + ENV["OSUSUME_BOT_SECRET"])
  osusume({"text"=> "!osusume! #{params[:name]}"})
  open "http://lingr.com/api/room/say?room=computer_science&bot=osusume&text=#{CGI.escape("'#{params[:name]}' がたぶんWebから削除されました")}&bot_verifier=#{bot_verifier}"
  '{"status": "OK"}'
end

post '/api' do
  content_type :json
  {:osusume => "#{osusume ({"text"=> params[:text]})}"}.to_json
end

post '/lingr' do
  json = JSON.parse(request.body.string)
  ret = ''
  json["events"].each do |e|
    ret += "#{osusume e['message']}" if e['message']
  end
  ret.rstrip[0..999]
end
