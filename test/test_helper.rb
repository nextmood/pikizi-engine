ENV["RAILS_ENV"] = "test"
require File.expand_path(File.dirname(__FILE__) + "/../config/environment")
require File.expand_path(File.dirname(__FILE__) + "/blueprints")

require 'test_help'

#require 'shoulda'
#require 'mocha'



class ActiveSupport::TestCase

#  setup { Sham.reset }
  
  # Drop all collections after each test case.
  def teardown
    MongoMapper.database.collections.each do |coll|
      coll.remove
    end
  end


  # Make sure that each test case has a teardown
  # method to clear the db after each test.
  def inherited(base)
    base.define_method teardown do
      super
    end
  end
  
end
