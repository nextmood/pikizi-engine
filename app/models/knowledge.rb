require 'pikizi'
require 'xml'


class Knowledge < ActiveRecord::Base
    
  def pkz_knowledge() @pkz_knowledge ||= Pikizi::Knowledge.get_from_cache(key) end
  
end
