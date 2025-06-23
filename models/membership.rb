
class Membership < Sequel::Model
  many_to_one :user
  many_to_one :organization
end
