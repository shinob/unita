
class Meeting < Sequel::Model
  many_to_one :organization
  many_to_one :organizer, class: :User
  one_to_many :participants
  
end
