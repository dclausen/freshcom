defmodule Freshcom.IdentityPolicy do

  def authorize(%{_role_: "sysdev"} = req, _), do: {:ok, req}
  def authorize(%{_role_: "system"} = req, _), do: {:ok, req}
  def authorize(%{_role_: "appdev"} = req, _), do: {:ok, req}

  def authorize(%{_role_: role} = req, :list_user) when role in ["owner", "administrator"],
    do: {:ok, req}

  def authorize(%{requester_id: rid, identifiers: %{"id" => tid}} = req, :get_user) when rid == tid,
    do: {:ok, req}

  def authorize(%{_role_: role} = req, :get_user) when role in ["owner", "administrator"],
    do: {:ok, req}

  def authorize(_, _), do: {:error, :access_denied}
end