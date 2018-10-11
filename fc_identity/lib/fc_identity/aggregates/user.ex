defmodule FCIdentity.User do
  use TypedStruct

  import FCIdentity.Support, only: [struct_merge: 2]
  alias FCIdentity.{
    UserRegistrationRequested,
    UserAdded,
    UserRegistered,
    UserDeleted,
    PasswordResetTokenGenerated
  }

  typedstruct do
    field :id, String.t()
    field :account_id, String.t()
    field :default_account_id, String.t()

    field :type, String.t()
    field :status, String.t()
    field :username, String.t()
    field :password_hash, String.t()
    field :email, String.t()

    field :first_name, String.t()
    field :last_name, String.t()
    field :name, String.t()

    field :password_reset_token, String.t()
    field :password_reset_token_expires_at, DateTime.t()
  end

  def apply(state, %UserRegistrationRequested{}), do: state

  def apply(state, %UserAdded{} = event) do
    %{state | id: event.user_id}
    |> struct_merge(event)
  end

  def apply(state, %UserRegistered{} = event) do
    %{state | status: "active", default_account_id: event.default_account_id}
  end

  def apply(state, %UserDeleted{}) do
    %{state | status: "removed"}
  end

  def apply(state, %PasswordResetTokenGenerated{} = event) do
    %{state | password_reset_token: event.token, password_reset_token_expires_at: event.expires_at}
  end
end