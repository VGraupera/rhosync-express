require 'rubygems'
require 'sinatra'
require 'json'
require 'activesupport'
require 'time'

require 'object_value'
require 'source'

require 'wikipedia'

# the following two calls are to stub out the authentication used by rhosync

post '/apps/:app_name/sources/:source_name/client_login' do
  # return cookie with rhosync_session
  response.set_cookie("rhosync_session", "12345678901234567890;")
  status 200
end

get '/apps/:app_name/sources/:source_name/clientcreate' do
  content_type "application/json"
  { "client" => { "client_id"=> "1c857a6d-f6c2-409f-9c5b-314287ce3011",
                  "updated_at" => Time.now.iso8601, "created_at" => Time.now.iso8601,
                  "session" => nil, "user_id" => nil, "last_sync_token" =>nil
                }  
  }.to_json
end

# the "real work" begins here

#  Parameters: {"format"=>"json", "action"=>"ask", "client_id"=>"f59a8af1-de7b-47c7-8bbb-0c421e135dc3", 
#   "id"=>"Wikipedia", "p_size"=>"1000", "controller"=>"sources", "question"=>"life_the_universe_and_everything", 
#   "app_id"=>"Wikipedia", "ack_token"=>"12031510061397"}

get '/apps/:app_name/sources/:source_name/ask' do
  content_type "application/json"
  
  # TODO get this from a config file
  source=Source.new
  source.url = "http://en.m.wikipedia.org"
  source.id = 1
  
  adapter = Wikipedia.new(source)
  
  @object_values = adapter.ask(params)
  @token = params["ack_token"] || "doesnotmatter"
    
  erb :show
end

