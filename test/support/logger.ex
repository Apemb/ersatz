defmodule Mock.Logger do
  @callback log(String.t()) :: :ok | {:error, term()}
end

Ersatz.defmock(MockLogger, for: Mock.Config.Logger)