require 'ostruct'
require './database'

class Hash
  def self.to_ostructs(obj, memo={})
    return obj unless obj.is_a? Hash
    os = memo[obj] = OpenStruct.new
    obj.each { |k,v| os.send("#{k}=", memo[v] || to_ostructs(v, memo)) }
    os
  end
end

$config = Hash.to_ostructs(YAML.load_file(File.join(Dir.pwd, 'config.yml')))

before do
  headers "Content-Type" => "text/html; charset=utf-8"
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
  @title = 'Upload Video'
  haml :new
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

