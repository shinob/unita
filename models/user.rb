#require 'sequel'
#require 'bcrypt'

#DB = Sequel.sqlite('db/attendance.db')
Sequel::Model.plugin :timestamps
Sequel::Model.plugin :validation_helpers

class User < Sequel::Model
  one_to_many :memberships
  many_to_many :organizations, join_table: :memberships

  def system_admin?
    system_admin
  end

  def roles_for(organization_id)
    memberships_dataset.where(organization_id: organization_id).map(:role)
  end

  def password=(new_password)
    self.password_digest = BCrypt::Password.create(new_password)
  end

  def authenticate(password)
    BCrypt::Password.new(password_digest) == password
  rescue BCrypt::Errors::InvalidHash
    false
  end
  
  def validate
    super
    validates_unique :email
    validates_presence [:name, :email, :password_digest]
  end
  
end
