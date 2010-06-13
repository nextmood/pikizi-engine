require 'machinist/mongo' # or mongoid

require 'sham'
require 'faker'

Sham.idurl  { Faker::Name.name }
Sham.email { Faker::Internet.email }
Sham.label { Faker::Lorem.sentence }
Sham.body  { Faker::Lorem.paragraph }

Knowledge.blueprint do
  idurl
  label
end

Specification do
  idurl
  label
end

Rating do
  idurl
  label
end


ProductsQueryAtom.blueprint do
  name
  knowledge_id

end

ProductsQueryFromProductLabel.blueprint do
  product_id
  extension "none"
  product_label

end

Product.blueprint do
  idurl
  name
  knowledge_id
end