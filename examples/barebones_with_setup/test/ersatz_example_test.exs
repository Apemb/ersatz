defmodule ErsatzExampleTest do

  use ExUnit.Case
  doctest ErsatzExample

  test "posts name" do
    # Arrange
    name = "Jim"
    Ersatz.set_mock_implementation(&ExampleAPIMock.api_post/3, fn _, _, _ -> {:ok, nil} end)

    # Act
    result = ErsatzExample.post_name(name)

    # Assert
    assert result == {:ok, nil}

    api_mock_calls = Ersatz.get_mock_calls(&ExampleAPIMock.api_post/3)
    assert api_mock_calls == [[name, [], []]]
  end
end
