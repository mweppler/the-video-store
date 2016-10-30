require './database'
require './config/config_reader'


enable :sessions

before do
  headers "Content-Type" => "text/html; charset=utf-8"
  @logins = $config.admin_users
  p @logins
end

get '/' do
  @title = 'The Video Store'
  haml :index
end

post '/video/create' do  
  video            = Video.new(params[:video])
  image_attachment = video.attachments.new
  video_attachment = video.attachments.new
  image_attachment.handle_upload(params['image-file'])
  video_attachment.handle_upload(params['video-file'])
  if video.save
    @message = 'Video was saved.'
  else
    @message = 'Video was not saved.'
  end
  haml :create
end

get '/video/new' do
  process_request request, 'upload_video' do |req, username|
    @title = 'Upload Video'
    haml :new
  end
end

get '/video/list' do
  @title = 'Available Videos'
  @videos = Video.all(:order => [:title.desc])
  haml :list
end

get '/video/show/:id' do
  @video = Video.get(params[:id])
  @title = @video.title
  if @video
    haml :show
  else
    redirect '/video/list'
  end
end

get '/video/watch/:id' do
  process_request request, 'watch_video' do |req, username|
    video = Video.get(params[:id])
    if video
      @videos = {}
      video.attachments.each do |attachment|
        supported_mime_type = $config.supported_mime_types.select { |type| type['extension'] == attachment.extension }.first
        if supported_mime_type['type'] === 'video'
          @videos[attachment.id] = { :path => File.join($config.file_properties.video.link_path['public'.length..-1], attachment.filename) }
        end
      end
      if @videos.empty?
        redirect "/video/show/#{video.id}"
      else
        @title = "Watch #{video.title}"
        haml :watch
      end
    else
      redirect '/video/list'
    end

  end
end

get '/login' do
  @mess = params[:mess] if params[:mess]
  haml :login
end

post '/login' do
  username = params[:username]
  password = params[:password]

  if @logins[username] && @logins[username] == password
    session[:token] = token(username)
    redirect '/'
  else
    redirect '/login?mess=Unauthorized'
  end
end

post '/logout' do
  session[:token] = nil
  redirect '/'
end

def token username
  JWT.encode payload(username), ENV['JWT_SECRET'], 'HS256'
end

def payload username
  {
    exp: Time.now.to_i + 60 * 60,
    iat: Time.now.to_i,
    iss: ENV['JWT_ISSUER'],
    scopes: ['watch_video', 'upload_video', 'delete_video'],
    user: {
      username: username
    }
  }
end

def process_request req, scope
  begin
    options = { algorithm: 'HS256', iss: ENV['JWT_ISSUER'] }
    payload, header = JWT.decode session[:token], ENV['JWT_SECRET'], true, options

    scopes, user = payload['scopes'], payload['user']
    username = user['username'].to_sym

    if @logins[username] && scopes.include?(scope)
      yield req, username
    else
      redirect '/login'
    end

  rescue JWT::DecodeError
    [401, { 'Content-Type' => 'text/plain' }, ['A token must be passed.']]
  rescue JWT::ExpiredSignature
    [403, { 'Content-Type' => 'text/plain' }, ['The token has expired.']]
  rescue JWT::InvalidIssuerError
    [403, { 'Content-Type' => 'text/plain' }, ['The token does not have a valid issuer.']]
  rescue JWT::InvalidIatError
    [403, { 'Content-Type' => 'text/plain' }, ['The token does not have a valid "issued at" time.']]
  end
end

def call env
  begin
    options = { algorithm: 'HS256', iss: ENV['JWT_ISSUER'] }
    bearer = env.fetch('HTTP_AUTHORIZATION', '').slice(7..-1)
    payload, header = JWT.decode bearer, ENV['JWT_SECRET'], true, options

    env[:scopes] = payload['scopes']
    env[:user] = payload['user']

    #@app.call env
  rescue JWT::DecodeError
    [401, { 'Content-Type' => 'text/plain' }, ['A token must be passed.']]
  rescue JWT::ExpiredSignature
    [403, { 'Content-Type' => 'text/plain' }, ['The token has expired.']]
  rescue JWT::InvalidIssuerError
    [403, { 'Content-Type' => 'text/plain' }, ['The token does not have a valid issuer.']]
  rescue JWT::InvalidIatError
    [403, { 'Content-Type' => 'text/plain' }, ['The token does not have a valid "issued at" time.']]
  end
end