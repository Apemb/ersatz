defmodule ErsatzConfigTest do
  use ExUnit.Case, async: true

  doctest Ersatz.Config

  describe "setup/0" do
    test "loads the configuration" do
      assert MockLogger.log("hello") == {:error, :not_working}
    end
  end
end
