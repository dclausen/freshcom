defmodule Freshcom.Identity do
  import FCSupport.Struct
  import Freshcom.Context
  import Freshcom.IdentityPolicy

  use OK.Pipe

  alias Freshcom.Request
  alias FCIdentity.{
    RegisterUser,
    UpdateUserInfo,
    AddUser
  }
  alias FCIdentity.{
    UserRegistered,
    UserAdded,
    UserInfoUpdated
  }
  alias Freshcom.{Repo, Projector}
  alias Freshcom.{UserProjector, AccountProjector}
  alias Freshcom.{User, RefreshToken}

  def register_user(%Request{} = req) do
    req
    |> to_command(%RegisterUser{})
    |> dispatch_and_wait(UserRegistered)
    ~> Map.get(:user)
    ~> preload(req)
    |> to_response()
  end

  def add_user(%Request{} = req) do
    req
    |> to_command(%AddUser{})
    |> dispatch_and_wait(UserAdded)
    ~> Map.get(:user)
    ~> preload(req)
    |> to_response()
  end

  def update_user_info(%Request{} = req) do
    identifiers = atomize_keys(req.identifiers, ["id"])

    req
    |> to_command(%UpdateUserInfo{})
    |> Map.put(:user_id, identifiers[:id])
    |> dispatch_and_wait(UserInfoUpdated)
    ~> Map.get(:user)
    ~> preload(req)
    |> to_response()
  end

  def list_user(%Request{} = req) do
    req
    |> expand()
    |> authorize(:list_user)
    ~> to_query(User)
    ~> Repo.all()
    ~> preload(req)
    |> to_response()
  end

  def get_user(%Request{} = req) do
    req
    |> expand()
    |> authorize(:get_user)
    ~> to_query(User)
    ~> Repo.one()
    ~> preload(req)
    |> to_response()
  end

  def get_refresh_token(%Request{} = req) do
    req
    |> expand()
    |> authorize(:get_refresh_token)
    ~> to_query(RefreshToken)
    ~> Repo.one()
    |> to_response()
  end

  def get_account(%Request{} = req) do
    req
    |> expand()
    |> authorize(:get_account)
    ~> Map.get(:_account_)
    |> to_response()
  end

  defp dispatch_and_wait(cmd, event) do
    dispatch_and_wait(cmd, event, &wait/1)
  end

  defp wait(%UserRegistered{user_id: user_id}) do
    Projector.wait([
      {:user, UserProjector, &(&1.id == user_id)},
      {:live_account, AccountProjector, &(&1.owner_id == user_id && &1.mode == "live")},
      {:test_account, AccountProjector, &(&1.owner_id == user_id && &1.mode == "test")}
    ])
  end

  defp wait(%et{user_id: user_id}) when et in [UserAdded, UserInfoUpdated] do
    Projector.wait([
      {:user, UserProjector, &(&1.id == user_id)}
    ])
  end
end