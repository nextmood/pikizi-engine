require 'mongo_mapper'
require 'RMagick'

# describe a media (image, movie, etc...)
# id of the Media object == id of teh file in Grid
# behave has a bucket
class Media

  # retrieve a bucket
  # filename
  # content_type
  # file_length
  # upload_date
  # read (to return the binary data)
  def self.datas(media_id)
    media_id = Mongo::ObjectID.from_string(media_id) unless media_id.is_a?(Mongo::ObjectID)
    Media.grid.get(media_id)
  end




  def self.delete(media_id) Media.grid.delete(media_id) end

  private

  def self.grid
    @@grid ||= Mongo::Grid.new(MongoMapper.database)
  end


  def self.extension_valid?(extension) extension2mimetype.any? { |key, value| key == extension.split('.').last } end
  def self.mime_type_valid?(mime_type) extension2mimetype.any? { |key, value| value == mime_type } end
  def self.mime_type_from_extension(extension) extension2mimetype[extension.split('.').last] end


end


class MediaImage < Media

  def self.extension2mimetype()
    @@HASH_EXTENSION_2_MIMETYPE ||= {
            "png" => "image/png",
            "jpg" => "image/jpg" ,
            "jpeg" => "image/jpeg" ,
            "gif" => "image/gif"
            }
  end

  # main is mandatory !
  def self.versions() { "big" => [400,400], "main" => [200,200], "thumb" => [85,85], "gallery" => [50, 50] } end


  # fill a bucket, return a hash of version -> media_id
  def self.create(io, filename, content_type)
    img = Magick::Image.from_blob(io).first
    img = img.resize(400, 400)
    hash_version_media_ids = {}
    versions.each do |suffix, (w,h)|
      hash_version_media_ids[suffix] = Media.grid.put(img.resize(w,h).to_blob, "#{filename}_#{suffix}", :content_type => content_type)
    end
    hash_version_media_ids
  end

  def self.create_from_path(filename)
    File.open(filename, "r") do |aFile|
       # ... process the file
      Media::MediaImage.create(aFile.read, filename, mime_type_from_extension(filename))
    end
  end

end

class MediaText < Media

  def self.extension2mimetype()
    @@HASH_EXTENSION_2_MIMETYPE ||= {
            "html" => "text/html",
            "txt" => "text/txt" ,
            "htm" => "text/htm" ,
            }
  end

  # fill a bucket, return a hash of version -> media_id
  def self.create(media_file)
      Media.grid.put(media_file.read, media_file.original_filename, :content_type => media_file.content_type)
  end

end

