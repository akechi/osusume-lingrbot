require 'json'
require 'sinatra'
require 'bundler'
require 'uri'
require 'sass'
require 'slim'
require 'coffee-script'

Dir.chdir File.dirname(__FILE__)

set :port, 11615
set :environment, :production

Bundler.require
DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/osusume.db")

class Osusume
    include DataMapper::Resource
    property :id, Serial
    property :name, String
    property :content, String, :length => 256
    property :regexp, String, :length => 256
end
DataMapper.finalize
Osusume.auto_upgrade!

module Sinatra
  module Templates
    def slim(template, options={}, locals={})
      render :slim, template, options, locals
    end 
  end
end

def osusume(text)
  ret = ''
  if text =~ /^!osusume\s+(\S+)\s+(\S+)\s+(.+)$/m
    m = Regexp.last_match
    name = m[1]
    regexp = m[2]
    content = m[3]
    item = Osusume.first_or_create({:name => name})
    if item.update({:regexp => regexp, :content => content})
      ret += "Updated '#{name}'\n"
    end
  elsif text =~ /^!osusume\s+(\S+)$/
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
  elsif text =~ /^!osusume\?\s+(\S+)$/
    m = Regexp.last_match
    name = m[1]
    matched = false
    Osusume.all.each do |x|
      if Regexp.new(x[:regexp], Regexp::MULTILINE | Regexp::EXTENDED).match(text)
        ret += "Matched with '#{x[:name]}'\n"
        matched = true
      end
    end
    ret += "No matched" unless matched
  elsif text =~ /^!osusume!\s+(\S+)$/
    m = Regexp.last_match
    name = m[1]
    item = Osusume.first({:name => name})
    if item != nil
      item.destroy
      ret += "Deleted '#{name}'\n"
    else
      ret += "Not found '#{name}'\n"
    end
  elsif text =~ /^!osusume$/
    Osusume.all.each do |x|
      ret += "'#{x[:name]}' /#{x[:regexp]}/\n"
    end
  else
    res = []
    Osusume.all.each do |x|
      m = Regexp.new(x[:regexp], Regexp::MULTILINE | Regexp::EXTENDED).match(text)
      if m
        content = x[:content]
        (0...m.size).each do |x|
          content.gsub!("$!#{x}", URI.escape(m[x]))
          content.gsub!("$#{x}", m[x])
        end
        res << content
      end
    end
    ret = "#{res[rand res.size]}"
  end
  ret
end

helpers do
  include Rack::Utils; alias_method :h, :escape_html
end

get '/stylesheet.css' do
  sass :stylesheet
end

get '/osusume.js' do
  coffee :osusume
end

get '/' do
  @osusumes = Osusume.all
  slim :index
end

post '/api' do
	{:osusume => "#{osusume params[:text]}"}.to_json
end

post '/lingr' do
  json = JSON.parse(request.body.string)
  ret = ''
  json["events"].each do |e|
    ret += "#{osusume e['message']['text']}"
  end
  ret.rstrip[0..999]
end
