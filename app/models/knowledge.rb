require 'pikizi'
require 'xml'


class Knowledge < ActiveRecord::Base
    
  def pkz_knowledge() @pkz_knowledge ||= Pikizi::Knowledge.create_from_xml(key) end
  
end
