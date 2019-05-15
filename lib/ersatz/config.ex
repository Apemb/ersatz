defmodule Ersatz.Config do
  @moduledoc """
  Behaviour for Ersatz startup configuration

  This module should be configured in Mix.Config and available at
  `config :ersatz, config: Mock.Config`

  Using the mechanism will set Ersatz in global mode for your mocks to be available in your Application thread.

  As well as the mock.ex, mock_config.ex should be compiled
  with the rest of the project. Edit your `mix.exs` file to add the
  `test/support` directory to compilation paths:

      def project do
        [
          ...
          elixirc_paths: elixirc_paths(Mix.env),
          ...
        ]
      end

      defp elixirc_paths(:test), do: ["test/support", "lib"]
      defp elixirc_paths(_),     do: ["lib"]
  """

  @doc """
  In this function manage the initial configuration of your mocks that you need during your app's startup.

  ## Example
  ```
  defmodule Mock.Config do
    @behaviour Ersatz.Config

    def setup() do
      Ersatz.set_mock_implementation(&MockCalc.add/2, fn _, _ -> :whatever)
      :ok
    end
  end
  ```
  """
  @callback setup() :: :ok
end
