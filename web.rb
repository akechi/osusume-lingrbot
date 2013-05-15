require 'json'
require 'sinatra'
require 'bundler'
require 'uri'
require 'sass'
require 'slim'

set :port, 11615

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

helpers do
  include Rack::Utils; alias_method :h, :escape_html
end

get '/stylesheet.css' do
  sass :stylesheet
end

get '/' do
  @osusumes = Osusume.all
  slim :index
end

post '/lingr' do
  json = JSON.parse(request.body.string)
  ret = ""
  json["events"].each do |e|
    text = e['message']['text']
    if text =~ /^!osusume\s+(\S+)\s+(\S+)\s+(.+)$/m
      m = Regexp.last_match
      name = m[1]
      regexp = m[2]
      content = m[3]
      osusume = Osusume.first_or_create({:name => name})
      if osusume.update({:regexp => regexp, :content => content})
        ret += "updated '#{name}'\n"
      end
    elsif text =~ /^!osusume\s+(\S+)$/
      m = Regexp.last_match
      name = m[1]
      osusume = Osusume.first({:name => name})
      if osusume != nil
        ret += "Name: #{osusume[:name]}\n"
        ret += "Regexp: /#{osusume[:regexp]}/\n"
        ret += "Content: #{osusume[:content]}\n"
      else
        ret += "not found '#{name}'\n"
      end
    elsif text =~ /^!osusume\?\s+(\S+)$/
      m = Regexp.last_match
      name = m[1]
      matched = false
      Osusume.all.each do |x|
        if Regexp.new(x[:regexp], Regexp::MULTILINE | Regexp::EXTENDED).match(text)
          ret += "matched with '#{x[:name]}'\n"
          matched = true
        end
      end
      ret += "no matched" unless matched
    elsif text =~ /^!osusume!\s+(\S+)$/
      m = Regexp.last_match
      name = m[1]
      osusume = Osusume.first({:name => name})
      if osusume != nil
        osusume.destroy
        ret += "deleted '#{name}'\n"
      else
        ret += "not found '#{name}'\n"
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
      ret = res[rand res.size] or ''
    end
  end
  ret.rstrip[1..1000]
end
