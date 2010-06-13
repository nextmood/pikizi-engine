require 'test_helper'

class ProductsQueryTest < ActiveSupport::TestCase

  describe ProductsQuery do

    before do
      # This will make a ProductsQuery, a Knowledge, and a User (the author of
      # the ProductsQuery), and generate values for all their attributes:
      @knowledge = Knowledge.make # check blue print
      @products_query_label = ProductsQueryByLabel.make # check blue print
    end

    it "should not include comments marked as spam in the without_spam named scope" do
      Comment.without_spam.should_not include(@comment)
    end

  end

#  fixtures :knowledges
  
  # Replace this with your real tests.
#  test "create basic ProductsQuery Atom" do
#    knowledge = knowledges(:cellphones)
#    products_query_atom = ProductsQueryAtom.process_attributes(
#            :knowledge_id => knowledge.id,
#            :products_query_atom_type => "ProductsQueryFromProductLabel",
#            :product_label => "Blackberry Bold (AT&T)",
#            :and_similar => "none")
    
#    assert true
#  end

end
