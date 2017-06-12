class Api < Versioneye::Model

  include Mongoid::Document
  include Mongoid::Timestamps

  field :user_id            , type: String
  field :organisation_id    , type: String
  field :api_key            , type: String
  field :enterprise_projects, type: Integer, default: 1
  field :rate_limit         , type: Integer, default: 50
  field :comp_limit         , type: Integer, default: 50 # Component limit
  field :active             , type: Boolean, default: true
  field :update_di          , type: Boolean, default: false # Update Docker Images
  field :read_only          , type: Boolean, default: false


  index({ api_key: 1 }, { name: "api_key_index", unique: true, drop_dups: true, background: true })

  validates :api_key, presence: true,
                      length: {minimum: 20, maximum: 20},
                      uniqueness: true

  def self.by_user( user )
    Api.where(user_id: user[:_id].to_s).first
  end

  def self.create_new( user )
    new_api = Api.new(user_id: user.ids)
    new_api.generate_api_key!
    new_api.rate_limit = 50
    new_api.save
    new_api
  end

  def self.create_new_for_orga( organisation, read_only = false )
    new_api = Api.new( organisation_id: organisation.ids )
    new_api.generate_api_key!
    if organisation && organisation.plan
      new_api.rate_limit = organisation.plan.api_rate_limit
    end
    new_api.read_only = read_only
    new_api.save
    new_api
  end

  def self.generate_api_key( length = 20 )
    length = (length / 2.0).round
    length = 1 if length < 1
    SecureRandom.hex(length)
  end

  def generate_api_key!( length =  20 )
    self.api_key = Api.generate_api_key(length)
  end

  def component_bucket
    ApiCmp.where(:api_key => self.api_key)
  end

  def user
    User.find user_id
  rescue => e
    nil
  end

  def organisation
    Organisation.find organisation_id
  rescue => e
    nil
  end

  def calls_count
    ApiCall.where(:api_key => self.api_key).count
  end

end
