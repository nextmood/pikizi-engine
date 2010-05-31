require 'test_helper'

class ProductsQueryTest < ActiveSupport::TestCase
  # Replace this with your real tests.
  test "create basic ProductsQuery Atom" do
    knowledge = Knowledge.first
    products_query_atom = ProductsQueryAtom.process_attributes(knowledge,
            :products_query_atom_type => "ProductsQueryFromProductLabel",
            :product_label => "Blackberry Bold (AT&T)",
            :and_similar => false) 
    assert true
  end
end
