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
      in_all_modes(
        fn ->
          Ersatz.set_mock_implementation(&SciCalcMock.exponent/2, fn x, y -> x - y end)
          Ersatz.set_mock_implementation(&SciCalcMock.add/2, fn x, y -> x * y end)

          assert SciCalcMock.exponent(4, 4) == 0
          assert SciCalcMock.add(2, 3) == 6
        end
      )
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

  describe "set_mock_return_value/3" do

    test "works with multiple behaviours" do
      in_all_modes(
        fn ->
          Ersatz.set_mock_return_value(&SciCalcMock.exponent/2, 0)
          Ersatz.set_mock_return_value(&SciCalcMock.add/2, 6)

          assert SciCalcMock.exponent(4, 4) == 0
          assert SciCalcMock.add(2, 3) == 6
        end
      )
    end

    test "is invoked n times by the same process in all modes" do
      in_all_modes(
        fn ->
          Ersatz.set_mock_return_value(&CalcMock.add/2, 3, times: 2)
          Ersatz.set_mock_return_value(&CalcMock.mult/2, 5, times: 1)
          Ersatz.set_mock_return_value(&CalcMock.add/2, 0)

          assert CalcMock.add(2, 3) == 3
          assert CalcMock.add(3, 2) == 3
          assert CalcMock.add(:whatever, :whatever) == 0
          assert CalcMock.mult(3, 2) == 5
        end
      )
    end

    test "is invoked n times by any process in global mode" do
      set_ersatz_global()

      Ersatz.set_mock_return_value(&CalcMock.add/2, 3, times: 2)
      Ersatz.set_mock_return_value(&CalcMock.mult/2, 5, times: 1)
      Ersatz.set_mock_return_value(&CalcMock.add/2, 0)

      task =
        Task.async(
          fn ->
            assert CalcMock.add(2, 3) == 3
            assert CalcMock.add(3, 2) == 3
          end
        )

      Task.await(task)

      assert CalcMock.add(:whatever, :whatever) == 0
      assert CalcMock.mult(3, 2) == 5
    end

    test "is invoked n times by any process in private mode on Elixir 1.8" do
      set_ersatz_private()

      Ersatz.set_mock_return_value(&CalcMock.add/2, 3, times: 2)
      Ersatz.set_mock_return_value(&CalcMock.mult/2, 5, times: 1)
      Ersatz.set_mock_return_value(&CalcMock.add/2, 0)

      task =
        Task.async(
          fn ->
            assert CalcMock.add(2, 3) == 3
            assert CalcMock.add(3, 2) == 3
          end
        )

      Task.await(task)

      assert CalcMock.add(:whatever, :whatever) == 0
      assert CalcMock.mult(3, 2) == 5
    end

    test "is invoked n times by a sub-process in private mode on Elixir 1.8" do
      set_ersatz_private()

      Ersatz.set_mock_return_value(&CalcMock.add/2, 3, times: 2)
      Ersatz.set_mock_return_value(&CalcMock.mult/2, 5, times: 1)
      Ersatz.set_mock_return_value(&CalcMock.add/2, 0)

      task =
        Task.async(
          fn ->
            assert CalcMock.add(2, 3) == 3
            assert CalcMock.add(3, 2) == 3

            inner_task =
              Task.async(
                fn ->
                  assert CalcMock.add(:whatever, :whatever) == 0
                  assert CalcMock.mult(3, 2) == 5
                end
              )

            Task.await(inner_task)
          end
        )

      Task.await(task)
    end

    test "can be recharged" do
      Ersatz.set_mock_return_value(&CalcMock.add/2, 3, times: 1)
      assert CalcMock.add(2, 3) == 3

      Ersatz.set_mock_return_value(&CalcMock.add/2, 3, times: 1)
      assert CalcMock.add(3, 2) == 3
    end

    test "expectations are reclaimed if the global process dies" do
      task =
        Task.async(
          fn ->
            set_ersatz_global()

            Ersatz.set_mock_return_value(&CalcMock.add/2, :expected, times: 1)
            Ersatz.set_mock_return_value(&CalcMock.mult/2, :expected, times: :permanent)
          end
        )

      Task.await(task)

      assert_raise Ersatz.UnexpectedCallError, fn ->
        CalcMock.add(1, 1)
      end

      Ersatz.set_mock_return_value(&CalcMock.mult/2, 2, times: 1)

      assert CalcMock.mult(1, 1) == 2
    end

    test "raises if a non-mock is given" do
      assert_raise ArgumentError, ~r"module Unknown is not available", fn ->
        Ersatz.set_mock_return_value(&Unknown.add/2, :whatever)
      end

      assert_raise ArgumentError, ~r"module String is not a mock", fn ->
        Ersatz.set_mock_return_value(&String.add/2, :whatever)
      end
    end

    test "raises if function is not in behaviour" do
      assert_raise ArgumentError, ~r"unknown function oops/2 for mock CalcMock", fn ->
        Ersatz.set_mock_return_value(&CalcMock.oops/2, :whatever)
      end

      assert_raise ArgumentError, ~r"unknown function add/3 for mock CalcMock", fn ->
        Ersatz.set_mock_return_value(&CalcMock.add/3, :whatever)
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
      Ersatz.set_mock_return_value(&CalcMock.add/2, :whatever, times: 1)
      assert CalcMock.add(2, 3) == :whatever

      assert_raise Ersatz.UnexpectedCallError, ~r"expected CalcMock.add/2 to be called once", fn ->
        CalcMock.add(2, 3) == 5
      end

      Ersatz.set_mock_return_value(&CalcMock.add/2, :other, times: 1)
      assert CalcMock.add(2, 3) == :other

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
            Ersatz.set_mock_return_value(&CalcMock.add/2, :expected)
          end
        end
      )
      |> Task.await()
    end

    test "permanent mode allows repeated invocations" do
      in_all_modes(
        fn ->
          Ersatz.set_mock_return_value(&CalcMock.add/2, :expected, times: :permanent)
          assert CalcMock.add(1, 2) == :expected
          assert CalcMock.add(3, 4) == :expected
          assert CalcMock.add(2, 4) == :expected
        end
      )
    end

    test "permanent mode gives time constraint calls precedence" do
      in_all_modes(
        fn ->
          Ersatz.set_mock_return_value(&CalcMock.add/2, :permanent, times: :permanent)
          Ersatz.set_mock_return_value(&CalcMock.add/2, :temporary, times: 1)

          assert CalcMock.add(1, 1) == :temporary
        end
      )
    end

    test "permanent mode is invoked after temporary mocks are used" do
      in_all_modes(
        fn ->
          Ersatz.set_mock_return_value(&CalcMock.add/2, :permanent, times: :permanent)
          Ersatz.set_mock_return_value(&CalcMock.add/2, :temporary, times: 2)

          assert CalcMock.add(1, 1) == :temporary
          assert CalcMock.add(1, 1) == :temporary
          assert CalcMock.add(1, 1) == :permanent
        end
      )
    end

    test "permanent mode mocks overwrite earlier permanent mode mocks" do
      in_all_modes(
        fn ->
          Ersatz.set_mock_return_value(&CalcMock.add/2, :first, times: :permanent)
          Ersatz.set_mock_return_value(&CalcMock.add/2, :second, times: :permanent)

          assert CalcMock.add(1, 1) == :second
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

  describe "allow/3" do
    set_ersatz_private()

    test "allows different processes to share mocks from parent process" do
      parent_pid = self()

      {:ok, child_pid} =
        start_link_no_callers(
          fn ->
            assert_raise Ersatz.UnexpectedCallError, fn -> CalcMock.add(1, 1) end

            receive do
              :call_mock ->
                add_result = CalcMock.add(1, 1)
                mult_result = CalcMock.mult(1, 1)
                send(parent_pid, {:verify, add_result, mult_result})
            end
          end
        )

      Ersatz.set_mock_return_value(&CalcMock.add/2, :expected, times: 1)
      Ersatz.set_mock_implementation(&CalcMock.mult/2, fn _, _ -> :permanent end, times: :permanent)

      Ersatz.allow(CalcMock, self(), child_pid)

      send(child_pid, :call_mock)

      assert_receive {:verify, add_result, mult_result}
      assert add_result == :expected
      assert mult_result == :permanent
    end

    test "allows different processes to share mocks from child process" do
      parent_pid = self()

      Ersatz.set_mock_return_value(&CalcMock.add/2, :expected, times: 1)
      Ersatz.set_mock_implementation(&CalcMock.mult/2, fn _, _ -> :permanent end, times: :permanent)

      async_no_callers(
        fn ->
          assert_raise Ersatz.UnexpectedCallError, fn -> CalcMock.add(1, 1) end

          Ersatz.allow(CalcMock, parent_pid, self())

          assert CalcMock.add(1, 1) == :expected
          assert CalcMock.mult(1, 1) == :permanent
        end
      )
      |> Task.await()
    end

    test "allowances are transitive" do
      parent_pid = self()

      {:ok, child_pid} =
        start_link_no_callers(
          fn ->
            assert_raise(Ersatz.UnexpectedCallError, fn -> CalcMock.add(1, 1) end)

            receive do
              :call_mock ->
                add_result = CalcMock.add(1, 1)
                mult_result = CalcMock.mult(1, 1)
                send(parent_pid, {:verify, add_result, mult_result})
            end
          end
        )

      {:ok, transitive_pid} =
        Task.start_link(
          fn ->
            receive do
              :allow_mock ->
                CalcMock
                |> allow(self(), child_pid)

                send(child_pid, :call_mock)
            end
          end
        )

      Ersatz.set_mock_return_value(&CalcMock.add/2, :expected, times: 1)
      Ersatz.set_mock_implementation(&CalcMock.mult/2, fn _, _ -> :permanent end, times: :permanent)

      Ersatz.allow(CalcMock, self(), transitive_pid)

      send(transitive_pid, :allow_mock)

      receive do
        {:verify, add_result, mult_result} ->
          assert add_result == :expected
          assert mult_result == :permanent
          assert length(Ersatz.get_mock_calls(&CalcMock.add/2)) == 1
      after
        1000 ->
          assert length(Ersatz.get_mock_calls(&CalcMock.add/2)) == 1
      end
    end

    test "allowances are reclaimed if the owner process dies" do
      parent_pid = self()

      task =
        Task.async(
          fn ->
            Ersatz.set_mock_return_value(&CalcMock.add/2, :expected, times: 1)
            Ersatz.set_mock_implementation(&CalcMock.mult/2, fn _, _ -> :permanent end, times: :permanent)

            Ersatz.allow(CalcMock, self(), parent_pid)
          end
        )

      Task.await(task)

      assert_raise Ersatz.UnexpectedCallError, fn ->
        CalcMock.add(1, 1)
      end

      Ersatz.set_mock_return_value(&CalcMock.add/2, :new, times: 1)

      assert CalcMock.add(1, 1) == :new
    end

    test "allowances support locally registered processes" do
      parent_pid = self()
      process_name = :test_process

      {:ok, child_pid} =
        Task.start_link(
          fn ->
            receive do
              :call_mock ->
                add_result = CalcMock.add(1, 1)
                send(parent_pid, {:verify, add_result})
            end
          end
        )

      Process.register(child_pid, process_name)

      Ersatz.set_mock_return_value(&CalcMock.add/2, :expected, times: 1)

      Ersatz.allow(CalcMock, self(), process_name)

      send(:test_process, :call_mock)

      assert_receive {:verify, add_result}
      assert add_result == :expected
    end

    test "allowances support processes registered through a Registry" do
      defmodule CalculatorServer do
        use GenServer

        def init(args) do
          {:ok, args}
        end

        def handle_call(:call_mock, _from, []) do
          add_result = CalcMock.add(1, 1)
          {:reply, add_result, []}
        end
      end

      {:ok, _} = Registry.start_link(keys: :unique, name: Registry.Test)
      name = {:via, Registry, {Registry.Test, :test_process}}
      {:ok, _} = GenServer.start_link(CalculatorServer, [], name: name)

      Ersatz.set_mock_return_value(&CalcMock.add/2, :expected, times: 1)
      Ersatz.allow(CalcMock, self(), name)

      add_result = GenServer.call(name, :call_mock)
      assert add_result == :expected
    end

    test "raises if you try to allow itself" do
      assert_raise ArgumentError, "owner_pid and allowed_pid must be different", fn ->
        Ersatz.allow(CalcMock, self(), self())
      end
    end

    test "raises if you try to allow already allowed process" do
      {:ok, child_pid} = Task.start_link(fn -> Process.sleep(:infinity) end)

      Ersatz.allow(CalcMock, self(), child_pid)

      Task.async(
        fn ->
          assert_raise ArgumentError, ~r"it is already allowed by", fn ->
            Ersatz.allow(CalcMock, self(), child_pid)
          end
        end
      )
      |> Task.await()
    end

    test "raises if you try to allow process with existing expectations set" do
      parent_pid = self()

      {:ok, pid} =
        Task.start_link(
          fn ->
            Ersatz.set_mock_return_value(&CalcMock.add/2, :expected, times: 1)

            send(parent_pid, :ready)
            Process.sleep(:infinity)
          end
        )

      assert_receive :ready

      assert_raise ArgumentError, ~r"the process has already defined its own expectations", fn ->
        Ersatz.allow(CalcMock, self(), pid)
      end
    end

    test "raises if you try to define expectations on allowed process" do
      parent_pid = self()

      Task.start_link(
        fn ->
          Ersatz.allow(CalcMock, self(), parent_pid)

          send(parent_pid, :ready)
          Process.sleep(:infinity)
        end
      )

      assert_receive :ready

      assert_raise ArgumentError, ~r"because the process has been allowed by", fn ->
        Ersatz.set_mock_return_value(&CalcMock.add/2, :expected, times: 1)
      end
    end

    test "is ignored if you allow process while in global mode" do
      set_ersatz_global()
      {:ok, child_pid} = Task.start_link(fn -> Process.sleep(:infinity) end)

      Task.async(
        fn ->
          mock = CalcMock
          assert Ersatz.allow(mock , self(), child_pid) == mock
        end
      )
      |> Task.await()
    end
  end

  defp async_no_callers(fun) do
    Task.async(
      fn ->
        Process.delete(:"$callers")
        fun.()
      end
    )
  end

  defp start_link_no_callers(fun) do
    Task.start_link(
      fn ->
        Process.delete(:"$callers")
        fun.()
      end
    )
  end
end
