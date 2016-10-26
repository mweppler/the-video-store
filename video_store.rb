require 'data_mapper'
require 'dm-core'
require 'dm-migrations'
require 'dm-sqlite-adapter'
require 'dm-timestamps'
require 'ostruct'


class Hash
  def self.to_ostructs(obj, memo={})
    return obj unless obj.is_a? Hash
    os = memo[obj] = OpenStruct.new
    obj.each { |k,v| os.send("#{k}=", memo[v] || to_ostructs(v, memo)) }
    os
  end
end

$config = Hash.to_ostructs(YAML.load_file(File.join(Dir.pwd, 'config.yml')))

configure do
  DataMapper::setup(:default, File.join('sqlite3://', Dir.pwd, 'db/development.db'))
end

class Video
  include DataMapper::Resource

  has n, :attachments

  property :id,           Serial
  property :created_at,   DateTime
  property :description,  Text
  property :genre,        String
  property :length,       Integer
  property :title,        String
  property :updated_at,   DateTime
end

class Attachment
  include DataMapper::Resource

  belongs_to :video

  property :id,         Serial
  property :created_at, DateTime
  property :extension,  String
  property :filename,   String
  property :mime_type,  String
  property :path,       Text
  property :size,       Integer
  property :updated_at, DateTime

  def handle_upload(file)
    self.extension = File.extname(file[:filename]).sub(/^\./, '').downcase
    supported_mime_type = $config.supported_mime_types.select { |type| type['extension'] == self.extension }.first
    return false unless supported_mime_type

    self.filename  = file[:filename]
    self.mime_type = file[:type]
    self.path      = File.join(Dir.pwd, $config.file_properties.send(supported_mime_type['type']).absolute_path, file[:filename])
    self.size      = File.size(file[:tempfile])
    File.open(path, 'wb') do |f|
      f.write(file[:tempfile].read)
    end
    FileUtils.symlink(self.path, File.join($config.file_properties.send(supported_mime_type['type']).link_path, file[:filename]))
  end
end

configure :development do
  DataMapper.finalize
  DataMapper.auto_upgrade!
end

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

