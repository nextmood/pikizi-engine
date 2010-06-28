
require 'machinist/mongo_mapper'

require 'sham'
require 'faker'

Sham.idurl  { Faker::Name.name }
Sham.email { Faker::Internet.email }
Sham.label { Faker::Lorem.sentence }
Sham.body  { Faker::Lorem.paragraph }

TextSource.blueprint do
  content_raw { Sham.body }
end
