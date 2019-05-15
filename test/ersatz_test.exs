defmodule ErsatzTest do
  use ExUnit.Case, async: true

  import Ersatz
  doctest Ersatz

  defmodule Calculator do
    @callback add(integer(), integer()) :: integer()
    @callback minus(integer(), integer()) :: integer()
    @callback mult(integer(), integer()) :: integer()
  end

  defmodule ScientificCalculator do
    @callback exponent(integer(), integer()) :: integer()
    @callback sin(integer()) :: float()
    @optional_callbacks [sin: 1]
  end

  defmock(CalcMock, for: Calculator)
  defmock(SciCalcMock, for: [Calculator, ScientificCalculator])

  def in_all_modes(callback) do
    set_ersatz_global()
    callback.()
    set_ersatz_private()
    callback.()
  end

  describe "defmock/2" do
    test "raises for unknown module" do
      assert_raise ArgumentError, ~r"module Unknown is not available", fn ->
        defmock(MyMock, for: Unknown)
      end
    end

    test "raises for non behaviour" do
      assert_raise ArgumentError, ~r"module String is not a behaviour", fn ->
        defmock(MyMock, for: String)
      end
    end

    test "raises if :for is missing" do
      assert_raise ArgumentError, ":for option is required on defmock", fn ->
        defmock(MyMock, [])
      end
    end

    test "accepts a list of behaviours" do
      assert defmock(MyMock, for: [Calculator, ScientificCalculator])
    end

    test "defines a mock function for all callbacks by default" do
      defmock(MyScientificMock, for: ScientificCalculator)
      all_callbacks = ScientificCalculator.behaviour_info(:callbacks)
      assert all_callbacks -- MyScientificMock.__info__(:functions) == []
    end

    test "accepts a list of callbacks to skip" do
      defmock(
        MyMultiMock,
        for: [Calculator, ScientificCalculator],
        skip_optional_callbacks: [
          sin: 1
        ]
      )

      all_callbacks = ScientificCalculator.behaviour_info(:callbacks)
      assert all_callbacks -- MyMultiMock.__info__(:functions) == [sin: 1]
    end

    test "accepts false to indicate all functions should be generated" do
      defmock(MyFalseMock, for: [Calculator, ScientificCalculator], skip_optional_callbacks: false)

      all_callbacks = ScientificCalculator.behaviour_info(:callbacks)
      assert all_callbacks -- MyFalseMock.__info__(:functions) == []
    end

    test "accepts true to indicate no optional functions should be generated" do
      defmock(MyTrueMock, for: [Calculator, ScientificCalculator], skip_optional_callbacks: true)
      all_callbacks = ScientificCalculator.behaviour_info(:callbacks)
      assert all_callbacks -- MyTrueMock.__info__(:functions) == [sin: 1]
    end

    test "raises if :skip_optional_callbacks is not a list or boolean" do
      assert_raise ArgumentError,
                   ":skip_optional_callbacks is required to be a list or boolean",
                   fn ->
                     defmock(MyMock, for: Calculator, skip_optional_callbacks: 42)
                   end
    end

    test "raises if a callback in :skip_optional_callbacks does not exist" do
      expected_error =
        "all entries in :skip_optional_callbacks must be an optional callback in" <>
        " one of the behaviours specified in :for. {:some_other_function, 0} was not in the list" <>
        " of all optional callbacks: []"

      assert_raise ArgumentError, expected_error, fn ->
        defmock(
          MyMock,
          for: Calculator,
          skip_optional_callbacks: [
            some_other_function: 0
          ]
        )
      end
    end

    test "raises if a callback in :skip_optional_callbacks is not an optional callback" do
      expected_error =
        "all entries in :skip_optional_callbacks must be an optional callback in" <>
        " one of the behaviours specified in :for. {:exponent, 2} was not in the list" <>
        " of all optional callbacks: [sin: 1]"

      assert_raise ArgumentError, expected_error, fn ->
        defmock(
          MyMock,
          for: ScientificCalculator,
          skip_optional_callbacks: [
            exponent: 2
          ]
        )
      end
    end
  end

  describe "set_mock_implementation/3" do

    test "works with multiple behaviours" do
      Ersatz.set_mock_implementation(&SciCalcMock.exponent/2, fn x, y -> x - y end)
      Ersatz.set_mock_implementation(&SciCalcMock.add/2, fn x, y -> x * y end)

      assert SciCalcMock.exponent(4, 4) == 0
      assert SciCalcMock.add(2, 3) == 6
    end

    test "is invoked n times by the same process in private mode" do
      set_ersatz_private()

      Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y -> x + y end, times: 2)
      Ersatz.set_mock_implementation(&CalcMock.mult/2, fn x, y -> x * y end, times: 1)
      Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> 0 end)

      assert CalcMock.add(2, 3) == 5
      assert CalcMock.add(3, 2) == 5
      assert CalcMock.add(:whatever, :whatever) == 0
      assert CalcMock.mult(3, 2) == 6
    end

    test "is invoked n times by any process in global mode" do
      set_ersatz_global()

      Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y -> x + y end, times: 2)
      Ersatz.set_mock_implementation(&CalcMock.mult/2, fn x, y -> x * y end, times: 1)
      Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> 0 end)

      task =
        Task.async(
          fn ->
            assert CalcMock.add(2, 3) == 5
            assert CalcMock.add(3, 2) == 5
          end
        )

      Task.await(task)

      assert CalcMock.add(:whatever, :whatever) == 0
      assert CalcMock.mult(3, 2) == 6
    end

    test "is invoked n times by any process in private mode on Elixir 1.8" do
      set_ersatz_private()

      Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y -> x + y end, times: 2)
      Ersatz.set_mock_implementation(&CalcMock.mult/2, fn x, y -> x * y end, times: 1)
      Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> 0 end)

      task =
        Task.async(
          fn ->
            assert CalcMock.add(2, 3) == 5
            assert CalcMock.add(3, 2) == 5
          end
        )

      Task.await(task)

      assert CalcMock.add(:whatever, :whatever) == 0
      assert CalcMock.mult(3, 2) == 6
    end

    test "is invoked n times by a sub-process in private mode on Elixir 1.8" do
      set_ersatz_private()

      Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y -> x + y end, times: 2)
      Ersatz.set_mock_implementation(&CalcMock.mult/2, fn x, y -> x * y end, times: 1)
      Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> 0 end)

      task =
        Task.async(
          fn ->
            assert CalcMock.add(2, 3) == 5
            assert CalcMock.add(3, 2) == 5

            inner_task =
              Task.async(
                fn ->
                  assert CalcMock.add(:whatever, :whatever) == 0
                  assert CalcMock.mult(3, 2) == 6
                end
              )

            Task.await(inner_task)
          end
        )

      Task.await(task)
    end

    test "can be recharged" do
      Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y -> x + y end, times: 1)
      assert CalcMock.add(2, 3) == 5

      Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y -> x + y end, times: 1)
      assert CalcMock.add(3, 2) == 5
    end

    test "expectations are reclaimed if the global process dies" do
      task =
        Task.async(
          fn ->
            set_ersatz_global()

            Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> :expected end, times: 1)
            Ersatz.set_mock_implementation(&CalcMock.mult/2, fn _, _ -> :expected end, times: :permanent)
          end
        )

      Task.await(task)

      assert_raise Ersatz.UnexpectedCallError, fn ->
        CalcMock.add(1, 1)
      end

      Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y -> x + y end, times: 1)

      assert CalcMock.add(1, 1) == 2
    end

    test "raises if a non-mock is given" do
      assert_raise ArgumentError, ~r"module Unknown is not available", fn ->
        Ersatz.set_mock_implementation(&Unknown.add/2, fn x, y -> x + y end)
      end

      assert_raise ArgumentError, ~r"module String is not a mock", fn ->
        Ersatz.set_mock_implementation(&String.add/2, fn x, y -> x + y end)
      end
    end

    test "raises if function is not in behaviour" do
      assert_raise ArgumentError, ~r"unknown function oops/2 for mock CalcMock", fn ->
        Ersatz.set_mock_implementation(&CalcMock.oops/2, fn x, y -> x + y end)
      end

      assert_raise ArgumentError, ~r"unknown function add/3 for mock CalcMock", fn ->
        Ersatz.set_mock_implementation(&CalcMock.add/3, fn x, y, z -> x + y + z end)
      end
    end

    test "raises if replacement function does not have the arity of mock function" do
      assert_raise ArgumentError, ~r"replacement function and add/2 do not have same arity", fn ->
        Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y, z -> x + y + z end)
      end
    end

    test "raises if there is no implementation defined for function" do
      assert_raise Ersatz.UnexpectedCallError,
                   ~r"no implementation defined for CalcMock\.add/2.*with args \[2, 3\]",
                   fn ->
                     CalcMock.add(2, 3) == 5
                   end
    end

    test "raises if all implementations are consumed" do
      Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y -> x + y end, times: 1)
      assert CalcMock.add(2, 3) == 5

      assert_raise Ersatz.UnexpectedCallError, ~r"expected CalcMock.add/2 to be called once", fn ->
        CalcMock.add(2, 3) == 5
      end

      Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y -> x + y end, times: 1)
      assert CalcMock.add(2, 3) == 5

      msg = ~r"expected CalcMock.add/2 to be called 2 times"

      assert_raise Ersatz.UnexpectedCallError, msg, fn ->
        CalcMock.add(2, 3) == 5
      end
    end

    test "raises if you try to add expectations from non global process" do
      set_ersatz_global()

      Task.async(
        fn ->
          msg =
            ~r"Only the process that set Ersatz to global can set expectations/stubs in global mode"

          assert_raise ArgumentError, msg, fn ->
            Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> :expected end)
          end
        end
      )
      |> Task.await()
    end

    test "permanent mode allows repeated invocations" do
      in_all_modes(
        fn ->
          Ersatz.set_mock_implementation(&CalcMock.add/2, fn x, y -> x + y end, times: :permanent)
          assert CalcMock.add(1, 2) == 3
          assert CalcMock.add(3, 4) == 7
          assert CalcMock.add(2, 4) == 6
        end
      )
    end

    test "permanent mode gives time constraint calls precedence" do
      in_all_modes(
        fn ->
          Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> :permanent end, times: :permanent)
          Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> :temporary end, times: 1)

          assert CalcMock.add(1, 1) == :temporary
        end
      )
    end

    test "permanent mode is invoked after temporary mocks are used" do
      in_all_modes(
        fn ->
          Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> :permanent end, times: :permanent)
          Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> :temporary end, times: 2)

          assert CalcMock.add(1, 1) == :temporary
          assert CalcMock.add(1, 1) == :temporary
          assert CalcMock.add(1, 1) == :permanent
        end
      )
    end

    test "permanent mode mocks overwrite earlier permanent mode mocks" do
      in_all_modes(
        fn ->
          Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> 25 end, times: :permanent)
          Ersatz.set_mock_implementation(&CalcMock.add/2, fn _, _ -> 42 end, times: :permanent)

          assert CalcMock.add(1, 1) == 42
        end
      )
    end
  end

  describe "get_mock_calls/1" do

    test "gets function calls argument in private mode" do
      set_ersatz_private()
      Ersatz.set_mock_implementation(&CalcMock.minus/2, fn _, _ -> :whatever end)

      CalcMock.minus(2, 3)
      CalcMock.minus(5, 7)

      minus_calls = Ersatz.get_mock_calls(&CalcMock.minus/2)

      assert minus_calls == [[2, 3], [5, 7]]
    end

    test "gets function calls argument in global mode" do
      set_ersatz_global()
      Ersatz.set_mock_implementation(&CalcMock.minus/2, fn _, _ -> :whatever end)

      CalcMock.minus(2, 3)
      CalcMock.minus(5, 7)

      minus_calls = Ersatz.get_mock_calls(&CalcMock.minus/2)

      assert minus_calls == [[2, 3], [5, 7]]
    end

    test "raises if a non-mock is given" do
      assert_raise ArgumentError, ~r"module Unknown is not available", fn ->
        Ersatz.get_mock_calls(&Unknown.add/2)
      end

      assert_raise ArgumentError, ~r"module String is not a mock", fn ->
        Ersatz.get_mock_calls(&String.add/2)
      end
    end

    test "raises if function is not in behaviour" do
      assert_raise ArgumentError, ~r"unknown function oops/2 for mock CalcMock", fn ->
        Ersatz.get_mock_calls(&CalcMock.oops/2)
      end

      assert_raise ArgumentError, ~r"unknown function add/3 for mock CalcMock", fn ->
        Ersatz.get_mock_calls(&CalcMock.add/3)
      end
    end
  end

  describe "clear_mock_calls/1" do

    test "deletes function calls argument of process in private mode" do
      set_ersatz_private()
      Ersatz.set_mock_implementation(&CalcMock.minus/2, fn _, _ -> :whatever end)

      CalcMock.minus(2, 3)
      CalcMock.minus(5, 7)

      first_minus_calls = Ersatz.get_mock_calls(&CalcMock.minus/2)
      Ersatz.clear_mock_calls(&CalcMock.minus/2)

      CalcMock.minus(1, 2)

      second_minus_calls = Ersatz.get_mock_calls(&CalcMock.minus/2)

      assert first_minus_calls == [[2, 3], [5, 7]]
      assert second_minus_calls == [[1, 2]]
    end

    test "deletes function calls argument of process in global mode" do
      set_ersatz_global()
      Ersatz.set_mock_implementation(&CalcMock.minus/2, fn _, _ -> :whatever end)

      CalcMock.minus(2, 3)
      CalcMock.minus(5, 7)

      first_minus_calls = Ersatz.get_mock_calls(&CalcMock.minus/2)
      Ersatz.clear_mock_calls(&CalcMock.minus/2)

      CalcMock.minus(1, 2)

      second_minus_calls = Ersatz.get_mock_calls(&CalcMock.minus/2)

      assert first_minus_calls == [[2, 3], [5, 7]]
      assert second_minus_calls == [[1, 2]]
    end

    test "raises if a non-mock is given" do
      assert_raise ArgumentError, ~r"module Unknown is not available", fn ->
        Ersatz.clear_mock_calls(&Unknown.add/2)
      end

      assert_raise ArgumentError, ~r"module String is not a mock", fn ->
        Ersatz.clear_mock_calls(&String.add/2)
      end
    end

    test "raises if function is not in behaviour" do
      assert_raise ArgumentError, ~r"unknown function oops/2 for mock CalcMock", fn ->
        Ersatz.clear_mock_calls(&CalcMock.oops/2)
      end

      assert_raise ArgumentError, ~r"unknown function add/3 for mock CalcMock", fn ->
        Ersatz.clear_mock_calls(&CalcMock.add/3)
      end
    end
  end
end
