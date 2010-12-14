require 'sinatra'
require 'haml'
require 'appengine-apis/users'
require 'appengine-apis/urlfetch'
require 'appengine-apis/logger'
require "appli"

set :haml, :attr_wrapper => '"', :ugly => false

helpers do
  include Rack::Utils
  alias_method :h, :escape_html

  def login_required
    redirect AppEngine::Users.create_login_url(request.url) unless @current_user
  end

  def logger
    @logger ||= AppEngine::Logger.new
  end

  def current_user
    @current_user
  end
end

before do
  @current_user = AppEngine::Users.current_user
end

get '/' do
  @apps = Appli.all(:user => current_user) if current_user
  haml :index
end

post '/' do
  login_required
  attrs = { :heroku_user => params[:heroku_user], :heroku_pass => params[:heroku_pass], :app_name => params[:app_name], :newrelic_key => params[:newrelic_key]}
  @app = Appli.new(attrs)
  @app.user = @current_user
  resp = @app.save
  logger.info resp
  redirect "/"
end

get "/alignment" do
  Appli.all.each do |app|
    logger.info "#{app.heroku_user}:#{app.app_name}| #{app.current_dyno} => #{app.adjust_dyno}"
  end
  return "Success"
end
