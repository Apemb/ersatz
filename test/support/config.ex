defmodule Mock.Config do
  @moduledoc false

  @behaviour Ersatz.Config

  defmodule Logger do
    @callback log(String.t()) :: :ok | {:error, term()}
  end

  def setup do
    Ersatz.set_mock_implementation(&MockLogger.log/1, fn _ -> {:error, :not_working} end)
    :ok
  end
end
