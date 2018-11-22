defmodule Freshcom.Identity do
  import FCSupport.Normalization, only: [atomize_keys: 2]
  import Freshcom.Context
  import Freshcom.IdentityPolicy

  use OK.Pipe

  alias Freshcom.{Context, Request}
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

  @spec register_user(Request.t()) :: Context.resp()
  def register_user(%Request{} = req) do
    req
    |> to_command(%RegisterUser{})
    |> dispatch_and_wait(UserRegistered)
    ~> Map.get(:user)
    ~> preload(req)
    |> to_response()
  end

  @spec add_user(Request.t()) :: Context.resp()
  def add_user(%Request{} = req) do
    req
    |> to_command(%AddUser{})
    |> dispatch_and_wait(UserAdded)
    ~> Map.get(:user)
    ~> preload(req)
    |> to_response()
  end

  @spec update_user_info(Request.t()) :: Context.resp()
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

  @spec list_user(Request.t()) :: Context.resp()
  def list_user(%Request{} = req) do
    req
    |> expand()
    |> authorize(:list_user)
    ~> to_query(User)
    ~> Repo.all()
    ~> preload(req)
    |> to_response()
  end

  @spec get_user(Request.t()) :: Context.resp()
  def get_user(%Request{} = req) do
    req
    |> expand()
    |> authorize(:get_user)
    ~> account_id_by_identifiers()
    ~> to_query(User)
    ~> Repo.one()
    ~> check_password(req)
    ~> check_account_id(req)
    ~> preload(req)
    |> to_response()
  end

  defp account_id_by_identifiers(%{identifiers: %{"id" => _}} = req) do
    Request.put(req, :account_id, nil)
  end

  defp account_id_by_identifiers(req), do: req

  defp check_password(nil, _), do: nil

  defp check_password(user, %{identifiers: %{"password" => password}}) do
    if User.is_password_valid?(user, password) do
      user
    else
      nil
    end
  end

  defp check_password(user, _), do: user

  defp check_account_id(nil, _), do: nil
  defp check_account_id(%{account_id: nil} = user, _), do: user
  defp check_account_id(%{account_id: aid} = user, %{account_id: t_aid}) when aid == t_aid, do: user
  defp check_account_id(_, _), do: nil

  @spec get_refresh_token(Request.t()) :: Context.resp()
  def get_refresh_token(%Request{} = req) do
    req = expand(req)

    req
    |> authorize(:get_refresh_token)
    ~> get_refresh_token_normalize()
    ~> to_query(RefreshToken)
    ~> Repo.one()
    ~> RefreshToken.put_prefixed_id(req._account_)
    |> to_response()
  end

  defp get_refresh_token_normalize(%{identifiers: %{"id" => id}} = req) do
    Request.put(req, :identifiers, "id", RefreshToken.bare_id(id))
  end

  defp get_refresh_token_normalize(req), do: req

  @doc """
  Exchange the given refresh token identified by its ID for a refresh token of
  the same user but for the account specified by `account_id` of the request.

  If the given refresh token is already for the specified account, then it is simply
  returned.

  This function is intended for exchanging a live refresh token for a corresponding
  test refresh token.
  """
  @spec exchange_refresh_token(Request.t()) :: Context.resp()
  def exchange_refresh_token(%Request{} = req) do
    req = expand(req)

    req
    |> authorize(:exchange_refresh_token)
    ~> do_exchange_refresh_token()
    ~> RefreshToken.put_prefixed_id(req._account_)
    |> to_response()
  end

  defp do_exchange_refresh_token(%{_account_: nil}), do: nil

  defp do_exchange_refresh_token(%{_account_: account, identifiers: %{"id" => id}}) do
    refresh_token = Repo.get(RefreshToken, RefreshToken.bare_id(id))

    cond do
      is_nil(refresh_token) ->
        nil

      refresh_token.account_id == account.id ->
        refresh_token

      refresh_token.account_id == account.live_account_id ->
        Repo.get_by(RefreshToken, account_id: account.id, user_id: refresh_token.user_id)

      true ->
        nil
    end
  end

  @spec get_account(Request.t()) :: Context.resp()
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