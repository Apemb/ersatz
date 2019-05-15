defmodule Ersatz.Application do
  @moduledoc false

  use Application

  def start(_, _) do
    children = [Old.Ersatz.Server, Ersatz.Server]
    Supervisor.start_link(children, name: Ersatz.Supervisor, strategy: :one_for_one)
  end

  def start_phase(:setup_initial_configuration, _start_type, _phase_args) do

    case Application.get_env(:ersatz, :config, nil) do
      nil -> :ok
      configuration_module ->
        Ersatz.set_ersatz_global()
        setup_func = &(configuration_module.setup/0)
        setup_func.()
    end
  end
end
