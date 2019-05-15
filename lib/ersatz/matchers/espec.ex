defmodule Ersatz.Matchers.Espec do
  @moduledoc """
  Custom matchers to ease the use of espec.
  """

  alias Ersatz.Matchers.Espec.HaveBeenCalled
  alias Ersatz.Matchers.Espec.HaveBeenCalledWith

  @doc """
  Tests if the mock function was called.

  It is possible to specify the number of calls to expect or just that it was called at least once.

  Default argument option is `times: :at_least_once`.

  **Examples :**
  ```
  ## Expect mock function to have been called at least once.
  expect(&CalcMock.add/2) |> to(have_been_called())
  expect(&CalcMock.add/2) |> to(have_been_called(times: :at_least_once))

  ## Expect mock function to have been called exactly 2 times.
  expect(&CalcMock.add/2) |> to(have_been_called(times: 2))
  ```
  """
  def have_been_called(options \\ [times: :at_least_once]), do: {HaveBeenCalled, options}

  @doc """
  Tests if the mock function was called with the right arguments.

  Two possibilities :
  - Match on the totality of arguments with `exactly: `
  - Assert that the mock function was called at least once with provided arguments `at_least: `

  **Examples :**
  ```
  ## Expect mock function to have been called with exactly twice with 1, 2 on first call and 4, 0 on second call.
  expect(&CalcMock.add/2) |> to(have_been_called_with(exactly: [{1, 2}, {4, 0}]))

  ## Expect mock function to have been called with at least once with 1, 2.
  expect(&CalcMock.add/2) |> to(have_been_called(at_least: {1, 2}))
  ```
  """
  def have_been_called_with(arguments), do: {HaveBeenCalledWith, arguments}
end
