require 'sinatra'
require 'dm-core'
require 'haml'

set :haml, :attr_wrapper => '"', :ugly => false

DataMapper.setup(:default, "appengine://auto")

# Create your model class
class Heroku
  include DataMapper::Resource

  property :id, Serial
  property :user, User
  property :heroku_user, Text
  property :heroku_pass, Text
  property :app_name, Text
  property :newrelic_key, Text
end

# Make sure our template can use <%=h
helpers do
  include Rack::Utils
  alias_method :h, :escape_html
end

get '/' do
  @herokus = Heroku.all
  haml :index
end

post '/' do
  attrs = { :heroku_user => params[:heroku_user], :heroku_pass => params[:heroku_pass], :app_name => params[:app_name], :newrelic_key => params[:newrelic_key]}
  @heroku = Heroku.create(attrs)
  redirect "/"
end

get "/alignment" do
end
