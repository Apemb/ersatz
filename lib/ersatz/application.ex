defmodule Ersatz.Application do
  @moduledoc false

  use Application

  def start(_, _) do
    children = [Old.Ersatz.Server, Ersatz.Server]
    Supervisor.start_link(children, name: Ersatz.Supervisor, strategy: :one_for_one)
  end
end
