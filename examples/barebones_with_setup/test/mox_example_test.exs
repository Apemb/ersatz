defmodule ErsatzExampleTest do
  import Ersatz

  use ExUnit.Case
  doctest ErsatzExample

  setup :verify_on_exit!

  test "posts name" do
    name = "Jim"

    ExampleAPIMock
    |> expect(:api_post, fn ^name, [], [] -> {:ok, nil} end)

    assert ErsatzExample.post_name(name) == {:ok, nil}
  end
end
