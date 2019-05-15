defmodule Ersatz.Matchers.ESpec.HaveBeenCalled do
  @moduledoc false

  use ESpec.Assertions.Interface

  defp match(mock_function, [times: :at_least_once]) do
    calls = Ersatz.get_mock_calls(mock_function)

    has_been_called = length(calls) > 0
    {has_been_called, calls}
  end

  defp match(mock_function, [times: times]) when is_integer(times) and times >= 0 do
    calls = Ersatz.get_mock_calls(mock_function)

    has_been_called_enough = length(calls) == times
    {has_been_called_enough, calls}
  end

  defp success_message(mock_function, [times: :at_least_once], _calls, is_positive) do
    to = if is_positive, do: "has", else: "has not"

    "`#{inspect mock_function}` #{to} has be called at least once."
  end

  defp success_message(mock_function, [times: times], _calls, is_positive) do
    to = if is_positive, do: "has", else: "has not"

    "`#{inspect mock_function}` #{to} has be called #{times} times."
  end

  defp error_message(mock_function, [times: :at_least_once], calls, is_positive) do
    phrase = if is_positive, do: "to have been called at least once", else: "to have never been called"

    "Expected `#{inspect mock_function}` #{phrase}, but was called #{length(calls)} times."
  end

  defp error_message(mock_function, [times: times], calls, is_positive) do
    phrase = if is_positive, do: "to have been called", else: "to have not been called"

    "Expected `#{inspect mock_function}` #{phrase} exactly #{times} times, but was called #{length(calls)} times."
  end
end
