require 'data_mapper'
require 'dm-core'
require 'dm-migrations'
require 'dm-sqlite-adapter'
require 'dm-timestamps'


configure do
  DataMapper::setup(:default, File.join('sqlite3://', Dir.pwd, '../db/development.db'))
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

class User

end

configure :development do
  DataMapper.finalize
  DataMapper.auto_upgrade!
end
