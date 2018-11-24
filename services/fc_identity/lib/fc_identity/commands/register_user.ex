defmodule FCIdentity.RegisterUser do
  use TypedStruct
  use Vex.Struct

  alias FCIdentity.CommandValidator

  typedstruct do
    field :user_id, String.t()

    field :username, String.t()
    field :password, String.t()
    field :email, String.t()
    field :is_term_accepted, boolean, default: false

    field :first_name, String.t()
    field :last_name, String.t()
    field :name, String.t()

    field :account_name, String.t(), default: "Unamed Account"
    field :default_locale, String.t(), default: "en"
  end

  @email_regex Application.get_env(:fc_identity, :email_regex)

  validates :username, presence: true, length: [min: 3], by: &CommandValidator.unique_username/2
  validates :password, presence: true, length: [min: 8]
  validates :email, presence: true, format: @email_regex
  validates :is_term_accepted, acceptance: true

  validates :name, presence: true

  validates :account_name, presence: true
  validates :default_locale, presence: true
end
