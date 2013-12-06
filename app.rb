require "sinatra"
require 'koala'


enable :sessions
set :raise_errors, false
set :show_exceptions, false

# configure do
#   DataMapper.setup(:default, 'mysql://lasfidad85910:lasf59313@sql.lasfidadelmandarino.it/lasfidad85910')
#   DataMapper.finalize.auto_upgrade!
# end


# class MandarinoTimeTable
#   include DataMapper::Resource
#   property :id,         Serial    # An auto-increment integer key
#   property :userId,     String    # A varchar type string, for User Facebook ID
#   property :day,        Integer   # The Day
#   property :year,       Integer   # The Year
#   property :today,      Integer   # Number of tangerins
# end

# class Ladder
#   include DataMapper::Resource
#   property :id,         Serial    # An auto-increment integer key
#   property :userId,     String    # A varchar type string, for User Facebook ID
#   property :year,       Integer   # The Year
#   property :total,      Integer   # Number of total tangerines
# end


# Scope defines what permissions that we are asking the user to grant.
# In this example, we are asking for the ability to publish stories
# about using the app, access to what the user likes, and to be able
# to use their pictures.  You should rewrite this scope with whatever
# permissions your app needs.
# See https://developers.facebook.com/docs/reference/api/permissions/
# for a full list of permissions
#FACEBOOK_SCOPE = 'user_likes,user_photos'
FACEBOOK_SCOPE = ''

unless ENV["FACEBOOK_APP_ID"] && ENV["FACEBOOK_SECRET"]
  abort("missing env vars: please set FACEBOOK_APP_ID and FACEBOOK_SECRET with your app credentials")
end

before do
  # HTTPS redirect
  if settings.environment == :production && request.scheme != 'https'
    redirect "https://#{request.env['HTTP_HOST']}"
  end
end

helpers do
  def host
    request.env['HTTP_HOST']
  end

  def scheme
    request.scheme
  end

  def url_no_scheme(path = '')
    "//#{host}#{path}"
  end

  def url(path = '')
    "#{scheme}://#{host}#{path}"
  end

  def authenticator
    @authenticator ||= Koala::Facebook::OAuth.new(ENV["FACEBOOK_APP_ID"], ENV["FACEBOOK_SECRET"], url("/auth/facebook/callback"))
  end

  # allow for javascript authentication
  def access_token_from_cookie
    authenticator.get_user_info_from_cookies(request.cookies)['access_token']
  rescue => err
    warn err.message
  end

  def access_token
    session[:access_token] || access_token_from_cookie
  end

  # HH

  def checkDate
    year = (Time.now.year).to_s
    days = (Date.parse("31/12/#{year}").mjd - DateTime.now.mjd)
  end

  def getMandarini
    s = Hash.new

    s["goal"] = 275
    s["today"] = 5
    s["total"] = 10
    plus = 5
    days = checkDate

    if days >= 31
      s["message"] = "La sfida e' conclusa! Ci rivediamo il prossimo 1 Dicembre!"
    else
      s["message"] = "Mancano ancora #{days} giorni e sei a #{plus} rispetto alla timetable!"
    end

    return s
  end

  def writeMandarini(id, day, howmany = 0)
  end

end

# the facebook session expired! reset ours and restart the process
error(Koala::Facebook::APIError) do
  session[:access_token] = nil
  redirect "/auth/facebook"
end

get "/" do
  # Get base API Connection
  @graph  = Koala::Facebook::API.new(access_token)

  # Get public details of current application
  @app  =  @graph.get_object(ENV["FACEBOOK_APP_ID"])

  @message = "Quanti #mandarini hai mangiato oggi?"
  @stats = getMandarini

  if access_token
    @user    = @graph.get_object("me")
    @friends = @graph.get_connections('me', 'friends')
    @message = @stats["message"]
    # for other data you can always run fql
    @friends_using_app = @graph.fql_query("SELECT uid, name, is_app_user, pic_square FROM user WHERE uid in (SELECT uid2 FROM friend WHERE uid1 = me()) AND is_app_user = 1")
  end

  if checkDate > 31
    erb :finish
  else
    erb :index
  end
end

# used by Canvas apps - redirect the POST to be a regular GET
post "/" do
  redirect "/"
end

# used to close the browser window opened to post to wall/send to friends
get "/close" do
  "<body onload='window.close();'/>"
end

# Doesn't actually sign out permanently, but good for testing
get "/preview/logged_out" do
  session[:access_token] = nil
  request.cookies.keys.each { |key, value| response.set_cookie(key, '') }
  redirect '/'
end


# Allows for direct oauth authentication
get "/auth/facebook" do
  session[:access_token] = nil
  redirect authenticator.url_for_oauth_code(:permissions => FACEBOOK_SCOPE)
end

get '/auth/facebook/callback' do
  session[:access_token] = authenticator.get_access_token(params[:code])
  redirect '/'
end

# HH
get '/more' do
  howmany = params[:howmany]
  userId = params[:who]


  if howmany > 0
    @total = howmany
    #mandarino = MandarinoTimeTable.get(:userId => userId, :day => Time.now.day, :year => Time.now.year )

    erb :response
  else
    erb :error
  end

end


