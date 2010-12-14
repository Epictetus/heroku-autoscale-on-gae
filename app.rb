require 'sinatra'
require 'dm-core'
require "extlib"
require 'haml'
require 'appengine-apis/users'
require 'appengine-apis/urlfetch'
require 'appengine-apis/logger'

require "active_resource"
require "new_relic/control"
require "new_relic_api"

require 'heroku'
require "heroku/command"

require "fix_http_timeout_error"

set :haml, :attr_wrapper => '"', :ugly => false

DataMapper.setup(:default, "appengine://auto")
DataMapper.repository.adapter.singular_naming_convention!

# Create your model class
class Appli
  include DataMapper::AppEngineResource

  property :id, Serial
  property :user, User
  property :heroku_user, Text
  property :heroku_pass, Text
  property :app_name, Text
  property :newrelic_key, Text

  def adjust_dyno(dyno = self.next_dyno)
    heroku.set_dynos(self.app_name, dyno)
  end

  def threshold_value
    return @threshold_value if @threshold_value
    NewRelicApi.license_key = self.newrelic_key
    values = NewRelicApi::Account.find(:first).applications.first.threshold_values
    @threshold_value = values.detect{ |v| v.name == "Apdex" }.threshold_value
  end

  def heroku
    @heroku_client ||= Heroku::Client.new(self.heroku_user, self.heroku_pass)
  end

  def current_dyno(reload = false)
    return @current_dyno if !reload and @current_dyno
    @current_dyno = Integer(heroku.info(self.app_name)[:dynos])
  end

  def next_dyno
    @next_dyno ||= case threshold_value
                    when 0
                      1
                    when 1
                      if current_dyno > 1
                        (current_dyno - 1)
                      else
                        1
                      end
                    else
                      (current_dyno + threshold_value)
                    end
  end

  def validates_accessible
    begin
      threshold_value
      current_dyno
    rescue => e
      # errors.add
    end
  end
end

# Make sure our template can use <%=h
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
  @heroku = Appli.new(attrs)
  @heroku.user = @current_user
  @heroku.save
  redirect "/"
end

get "/alignment" do
  Appli.all.each do |app|
    logger.info "#{app.heroku_user}:#{app.app_name}| #{app.current_dyno} => #{app.adjust_dyno}"
  end
  return "Success"
end
