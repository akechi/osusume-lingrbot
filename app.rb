require 'json'
require 'sinatra'
require 'bundler'

Bundler.require
if ENV['VCAP_SERVICES'].nil?
    DataMapper::setup(:default, "sqlite3://#{Dir.pwd}/images.db")
else
    require 'json'
    svcs = JSON.parse ENV['VCAP_SERVICES']
    mysql = svcs.detect { |k,v| k =~ /^mysql/ }.last.first
    creds = mysql['credentials']
    user, pass, host, name = %w(user password host name).map { |key| creds[key] }
    DataMapper.setup(:default, "mysql://#{user}:#{pass}@#{host}/#{name}")
end
class Image
    include DataMapper::Resource
    property :id, Serial
    property :name, String
    property :content, String, :length => 256
    property :regexp, String, :length => 256
end
DataMapper.finalize
Image.auto_upgrade!

get '/' do
  "hello"
end

post '/lingr' do
  json = JSON.parse(request.body.string)
  ret = ""
  images = Image.all
  json["events"].map do |e|
    text = e['message']['text']
    if text =~ /^!osusume\s+(\S+)\s+(\S+)\s+(\S+)$/
      image = Image.first_or_create({:name => $1})
      if image.update({:regexp => $2, :content => $3})
        ret += "updated\n"
      end
    elsif text =~ /^!osusume\s+(\S+)$/
      image = Image.get({:name => $1})
      if image
        image.destroy
        ret += "deleted\n"
      end
    elsif text =~ /^!osusume!$/
      images.each do |x|
        ret += "#{x[:name]} #{x[:regexp]}\n"
      end
    else
      images.each do |x|
        if Regexp.new(x[:regexp]).match(text)
          ret += "#{x[:content]}\n"
        end
      end
    end
  end
  ret
end
