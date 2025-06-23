
class Participant < Sequel::Model
  many_to_one :meeting
  many_to_one :user
  
end
