
class Organization < Sequel::Model
  one_to_many :memberships
  one_to_many :meetings
  
  def before_create
    self.ical_token ||= SecureRandom.hex(16)
    super
  end
end
