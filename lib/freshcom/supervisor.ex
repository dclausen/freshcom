defmodule Freshcom.Supervisor do
  @moduledoc false

  use Supervisor

  def start_link do
    Supervisor.start_link(__MODULE__, [], name: __MODULE__)
  end

  def init(_) do
    children = [
      # Services
      FCIdentity.Supervisor,

      # Infrastructure
      Freshcom.PubSub,
      Freshcom.Repo,

      # Projectors
      Freshcom.AccountProjector,
      Freshcom.UserProjector,
      Freshcom.RefreshTokenProjector,
      Freshcom.AppProjector
    ]

    Supervisor.init(children, strategy: :one_for_one)
  end
end