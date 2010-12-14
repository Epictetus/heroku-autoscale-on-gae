require 'dm-core'
require "extlib"

require "active_resource"
require "new_relic/control"
require "new_relic_api"

require 'heroku'
require "heroku/command"

require "fix_http_timeout_error"

DataMapper.setup(:default, "appengine://auto")
DataMapper.repository.adapter.singular_naming_convention!

class Appli
  include DataMapper::AppEngineResource

  property :id, Serial
  property :user, User, :required => true
  property :heroku_user, Text, :required => true
  property :heroku_pass, Text, :required => true
  property :app_name, Text, :required => true
  property :newrelic_key, Text, :required => true

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

  def validates_authorize
    begin
      threshold_value
      current_dyno
      true
    rescue => e
      [ false, e ]
    end
  end
end
