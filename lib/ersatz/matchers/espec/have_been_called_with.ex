defmodule Ersatz.Matchers.ESpec.HaveBeenCalledWith do
  @moduledoc false

  use ESpec.Assertions.Interface

  defp match(mock_function, [exactly: expected_calls]) when is_list(expected_calls) do
    calls = Ersatz.get_mock_calls(mock_function)

    calls_with_tuple = Enum.map(calls, &(List.to_tuple(&1)))
    has_been_called_with_correct_arguments = calls_with_tuple == expected_calls
    {has_been_called_with_correct_arguments, calls_with_tuple}
  end

  defp match(mock_function, [at_least_once: expected_call]) when is_tuple(expected_call) do
    calls = Ersatz.get_mock_calls(mock_function)

    calls_with_tuple = Enum.map(calls, &(List.to_tuple(&1)))

    has_been_called_with_correct_argument = Enum.find_value(calls_with_tuple , false, &(&1 == expected_call))
    {has_been_called_with_correct_argument, calls_with_tuple}
  end

  defp success_message(mock_function, [exactly: expected_calls], _calls, is_positive) do
    to = if is_positive, do: "has", else: "has not"

    "`#{inspect mock_function}` #{to} been called with #{inspect expected_calls}."
  end

  defp success_message(mock_function, [at_least_once: expected_call], _calls, is_positive) do
    to = if is_positive, do: "has been called at least once", else: "has never been called"

    "`#{inspect mock_function}` #{to} with #{inspect expected_call}."
  end

  defp error_message(mock_function, [exactly: expected_calls], calls, is_positive) do
    phrase = if is_positive, do: "to have been called with", else: "to have not been called with"

    "Expected `#{inspect mock_function}` #{phrase} #{inspect expected_calls},
     but was instead called with #{inspect calls}."
  end

  defp error_message(mock_function, [at_least_once: expected_call], calls, is_positive) do
    phrase = if is_positive, do: "to have been called at least once", else: "to have never been called"

    "Expected `#{inspect mock_function}` #{phrase} with #{inspect expected_call},
     but was instead called with #{inspect calls}."
  end
end
