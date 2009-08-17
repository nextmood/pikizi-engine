require 'test_helper'

class KnowledgeTest < ActiveSupport::TestCase

  test "creating a model" do
    
    model = Pikizi::Knowledge.new("cellphone")
    model.add_feature("numeric", :label => "price interval", :value_min => 100, :value_max => 1000, :format => "$")

    model.add_feature("date", :label => "release date")
    model.add_feature("tag", :label => "status", :tags => ["announced", "released", "end of life"], :exclusive => true)

    cf = model.add_feature("header", :label => "caméra", :optional => true)
    cf.add_feature("numeric", :label => "nb pixels", :value_min => 0.3, :value_max => 15, :format => "Mpx")
    cf.add_feature("binary", :label => "autofocus")
    
    assert true
  end
end
