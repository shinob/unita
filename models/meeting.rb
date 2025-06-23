
class Meeting < Sequel::Model
  many_to_one :organization
  many_to_one :organizer, class: :User
  one_to_many :participants
  
  dataset_module do
    def enabled
      where(disabled: false)
    end
  end
  
end
