require 'mongo_mapper'

class Main
  include MongoMapper::Document

  key :titre, String # unique url

  many :totos, :polymorphic => true

end

class Toto

  include MongoMapper::Document

  key :url, String # unique url


end

class Titi < Toto


  key :label1, String # unique url

end


class Tata < Toto


  key :label2, String # unique url

end


def test_mongo()
  #MongoMapper.connection = XGen::Mongo::Driver::Mongo.new('hostname')
  MongoMapper.database = 'pikizi_mongodb'


  x = Main.create({:titre => 'cell_phones'})

  x.totos = []

  y1 = Titi.new; y1.url = 'cell_phones1'; y1.label1 = "Essai1"
  puts y1.inspect << " url=#{y1.url} label=#{y1.label1} #{y1.class} "
  x.totos <<   y1

  y2 = Tata.new; y2.url = 'cell_ph234'; y2.label2 = "Essai2"
  puts y2.inspect     << " url=#{y2.url} label=#{y2.label2} #{y2.class} "
  x.totos <<  y2

  puts "totos size=#{x.totos.size}"

  x.save
  

  x =  Main.find(:first, :conditions => { :titre => 'cell_phones' })

  puts "x size=#{x.inspect}"
  puts "totos size=#{x.totos.size}"

  y1,y2 = x.totos
  puts y1.inspect << " url=#{y1.url} label=#{y1.label1} #{y1.class} "
  puts y2.inspect     << " url=#{y2.url} label=#{y2.label2} #{y2.class}"
  
  x.destroy

end
