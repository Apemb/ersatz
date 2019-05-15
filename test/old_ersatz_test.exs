defmodule OldErsatzTest do
  use ExUnit.Case, async: true

  import Old.Ersatz
  doctest Old.Ersatz

  defmodule Calculator do
    @callback add(integer(), integer()) :: integer()
    @callback mult(integer(), integer()) :: integer()
  end

  defmodule ScientificCalculator do
    @callback exponent(integer(), integer()) :: integer()
    @callback sin(integer()) :: float()
    @optional_callbacks [sin: 1]
  end

  defmock(OldCalcMock, for: Calculator)
  defmock(OldSciCalcMock, for: [Calculator, ScientificCalculator])

  def in_all_modes(callback) do
    set_ersatz_global()
    callback.()
    set_ersatz_private()
    callback.()
  end

  describe "defmock/2" do
    test "raises for unknown module" do
      assert_raise ArgumentError, ~r"module Unknown is not available", fn ->
        defmock(MyOldMock, for: Unknown)
      end
    end

    test "raises for non behaviour" do
      assert_raise ArgumentError, ~r"module String is not a behaviour", fn ->
        defmock(MyOldMock, for: String)
      end
    end

    test "raises if :for is missing" do
      assert_raise ArgumentError, ":for option is required on defmock", fn ->
        defmock(MyOldMock, [])
      end
    end

    test "accepts a list of behaviours" do
      assert defmock(MyOldMock, for: [Calculator, ScientificCalculator])
    end

    test "defines a mock function for all callbacks by default" do
      defmock(MyOldScientificMock, for: ScientificCalculator)
      all_callbacks = ScientificCalculator.behaviour_info(:callbacks)
      assert all_callbacks -- MyScientificMock.__info__(:functions) == []
    end

    test "accepts a list of callbacks to skip" do
      defmock(MyOldMultiMock,
        for: [Calculator, ScientificCalculator],
        skip_optional_callbacks: [sin: 1]
      )

      all_callbacks = ScientificCalculator.behaviour_info(:callbacks)
      assert all_callbacks -- MyOldMultiMock.__info__(:functions) == [sin: 1]
    end

    test "accepts false to indicate all functions should be generated" do
      defmock(MyOldFalseMock, for: [Calculator, ScientificCalculator], skip_optional_callbacks: false)

      all_callbacks = ScientificCalculator.behaviour_info(:callbacks)
      assert all_callbacks -- MyFalseMock.__info__(:functions) == []
    end

    test "accepts true to indicate no optional functions should be generated" do
      defmock(MyOldTrueMock, for: [Calculator, ScientificCalculator], skip_optional_callbacks: true)
      all_callbacks = ScientificCalculator.behaviour_info(:callbacks)
      assert all_callbacks -- MyTrueMock.__info__(:functions) == [sin: 1]
    end

    test "raises if :skip_optional_callbacks is not a list or boolean" do
      assert_raise ArgumentError,
                   ":skip_optional_callbacks is required to be a list or boolean",
                   fn ->
                     defmock(MyOldMock, for: Calculator, skip_optional_callbacks: 42)
                   end
    end

    test "raises if a callback in :skip_optional_callbacks does not exist" do
      expected_error =
        "all entries in :skip_optional_callbacks must be an optional callback in" <>
          " one of the behaviours specified in :for. {:some_other_function, 0} was not in the list" <>
          " of all optional callbacks: []"

      assert_raise ArgumentError, expected_error, fn ->
        defmock(MyOldMock,
          for: Calculator,
          skip_optional_callbacks: [some_other_function: 0]
        )
      end
    end

    test "raises if a callback in :skip_optional_callbacks is not an optional callback" do
      expected_error =
        "all entries in :skip_optional_callbacks must be an optional callback in" <>
          " one of the behaviours specified in :for. {:exponent, 2} was not in the list" <>
          " of all optional callbacks: [sin: 1]"

      assert_raise ArgumentError, expected_error, fn ->
        defmock(MyOldMock,
          for: ScientificCalculator,
          skip_optional_callbacks: [exponent: 2]
        )
      end
    end
  end

  describe "expect/4" do
    test "works with multiple behaviours" do
      OldSciCalcMock
      |> expect(:exponent, fn x, y -> :math.pow(x, y) end)
      |> expect(:add, fn x, y -> x + y end)

      assert OldSciCalcMock.exponent(2, 3) == 8
      assert OldSciCalcMock.add(2, 3) == 5
    end

    test "is invoked n times by the same process in private mode" do
      set_ersatz_private()

      OldCalcMock
      |> expect(:add, 2, fn x, y -> x + y end)
      |> expect(:mult, fn x, y -> x * y end)
      |> expect(:add, fn _, _ -> 0 end)

      assert OldCalcMock.add(2, 3) == 5
      assert OldCalcMock.add(3, 2) == 5
      assert OldCalcMock.add(:whatever, :whatever) == 0
      assert OldCalcMock.mult(3, 2) == 6
    end

    test "is invoked n times by any process in global mode" do
      set_ersatz_global()

      OldCalcMock
      |> expect(:add, 2, fn x, y -> x + y end)
      |> expect(:mult, fn x, y -> x * y end)
      |> expect(:add, fn _, _ -> 0 end)

      task =
        Task.async(fn ->
          assert OldCalcMock.add(2, 3) == 5
          assert OldCalcMock.add(3, 2) == 5
        end)

      Task.await(task)

      assert OldCalcMock.add(:whatever, :whatever) == 0
      assert OldCalcMock.mult(3, 2) == 6
    end

    @tag :requires_caller_tracking
    test "is invoked n times by any process in private mode on Elixir 1.8" do
      set_ersatz_private()

      OldCalcMock
      |> expect(:add, 2, fn x, y -> x + y end)
      |> expect(:mult, fn x, y -> x * y end)
      |> expect(:add, fn _, _ -> 0 end)

      task =
        Task.async(fn ->
          assert OldCalcMock.add(2, 3) == 5
          assert OldCalcMock.add(3, 2) == 5
        end)

      Task.await(task)

      assert OldCalcMock.add(:whatever, :whatever) == 0
      assert OldCalcMock.mult(3, 2) == 6
    end

    @tag :requires_caller_tracking
    test "is invoked n times by a sub-process in private mode on Elixir 1.8" do
      set_ersatz_private()

      OldCalcMock
      |> expect(:add, 2, fn x, y -> x + y end)
      |> expect(:mult, fn x, y -> x * y end)
      |> expect(:add, fn _, _ -> 0 end)

      task =
        Task.async(fn ->
          assert OldCalcMock.add(2, 3) == 5
          assert OldCalcMock.add(3, 2) == 5

          inner_task =
            Task.async(fn ->
              assert OldCalcMock.add(:whatever, :whatever) == 0
              assert OldCalcMock.mult(3, 2) == 6
            end)

          Task.await(inner_task)
        end)

      Task.await(task)
    end

    test "allows asserting that function is not called" do
      OldCalcMock
      |> expect(:add, 0, fn x, y -> x + y end)

      msg = ~r"expected OldCalcMock.add/2 to be called 0 times but it has been called once"

      assert_raise Old.Ersatz.UnexpectedCallError, msg, fn ->
        OldCalcMock.add(2, 3) == 5
      end
    end

    test "can be recharged" do
      expect(OldCalcMock, :add, fn x, y -> x + y end)
      assert OldCalcMock.add(2, 3) == 5

      expect(OldCalcMock, :add, fn x, y -> x + y end)
      assert OldCalcMock.add(3, 2) == 5
    end

    test "expectations are reclaimed if the global process dies" do
      task =
        Task.async(fn ->
          set_ersatz_global()

          OldCalcMock
          |> expect(:add, fn _, _ -> :expected end)
          |> stub(:mult, fn _, _ -> :stubbed end)
        end)

      Task.await(task)

      assert_raise Old.Ersatz.UnexpectedCallError, fn ->
        OldCalcMock.add(1, 1)
      end

      OldCalcMock
      |> expect(:add, 1, fn x, y -> x + y end)

      assert OldCalcMock.add(1, 1) == 2
    end

    test "raises if a non-mock is given" do
      assert_raise ArgumentError, ~r"module Unknown is not available", fn ->
        expect(Unknown, :add, fn x, y -> x + y end)
      end

      assert_raise ArgumentError, ~r"module String is not a mock", fn ->
        expect(String, :add, fn x, y -> x + y end)
      end
    end

    test "raises if function is not in behaviour" do
      assert_raise ArgumentError, ~r"unknown function oops/2 for mock OldCalcMock", fn ->
        expect(OldCalcMock, :oops, fn x, y -> x + y end)
      end

      assert_raise ArgumentError, ~r"unknown function add/3 for mock OldCalcMock", fn ->
        expect(OldCalcMock, :add, fn x, y, z -> x + y + z end)
      end
    end

    test "raises if there is no expectation" do
      assert_raise Old.Ersatz.UnexpectedCallError,
                   ~r"no expectation defined for OldCalcMock\.add/2.*with args \[2, 3\]",
                   fn ->
                     OldCalcMock.add(2, 3) == 5
                   end
    end

    test "raises if all expectations are consumed" do
      expect(OldCalcMock, :add, fn x, y -> x + y end)
      assert OldCalcMock.add(2, 3) == 5

      assert_raise Old.Ersatz.UnexpectedCallError, ~r"expected OldCalcMock.add/2 to be called once", fn ->
        OldCalcMock.add(2, 3) == 5
      end

      expect(OldCalcMock, :add, fn x, y -> x + y end)
      assert OldCalcMock.add(2, 3) == 5

      msg = ~r"expected OldCalcMock.add/2 to be called 2 times"

      assert_raise Old.Ersatz.UnexpectedCallError, msg, fn ->
        OldCalcMock.add(2, 3) == 5
      end
    end

    test "raises if you try to add expectations from non global process" do
      set_ersatz_global()

      Task.async(fn ->
        msg =
          ~r"Only the process that set Old.Ersatz to global can set expectations/stubs in global mode"

        assert_raise ArgumentError, msg, fn ->
          OldCalcMock
          |> expect(:add, fn _, _ -> :expected end)
        end
      end)
      |> Task.await()
    end
  end

  describe "verify!/0" do
    test "verifies all mocks for the current process in private mode" do
      set_ersatz_private()

      verify!()
      expect(OldCalcMock, :add, fn x, y -> x + y end)

      message = ~r"expected OldCalcMock.add/2 to be invoked once but it was invoked 0 times"
      assert_raise Old.Ersatz.VerificationError, message, &verify!/0

      assert OldCalcMock.add(2, 3) == 5
      verify!()
      expect(OldCalcMock, :add, fn x, y -> x + y end)

      message = ~r"expected OldCalcMock.add/2 to be invoked 2 times but it was invoked once"
      assert_raise Old.Ersatz.VerificationError, message, &verify!/0
    end

    test "verifies all mocks for the current process in global mode" do
      set_ersatz_global()

      verify!()
      expect(OldCalcMock, :add, fn x, y -> x + y end)

      message = ~r"expected OldCalcMock.add/2 to be invoked once but it was invoked 0 times"
      assert_raise Old.Ersatz.VerificationError, message, &verify!/0

      task =
        Task.async(fn ->
          assert OldCalcMock.add(2, 3) == 5
        end)

      Task.await(task)

      verify!()
      expect(OldCalcMock, :add, fn x, y -> x + y end)

      message = ~r"expected OldCalcMock.add/2 to be invoked 2 times but it was invoked once"
      assert_raise Old.Ersatz.VerificationError, message, &verify!/0
    end
  end

  describe "verify!/1" do
    test "verifies all mocks for the current process in private mode" do
      set_ersatz_private()

      verify!(OldCalcMock)
      expect(OldCalcMock, :add, fn x, y -> x + y end)

      message = ~r"expected OldCalcMock.add/2 to be invoked once but it was invoked 0 times"
      assert_raise Old.Ersatz.VerificationError, message, &verify!/0

      assert OldCalcMock.add(2, 3) == 5
      verify!(OldCalcMock)
      expect(OldCalcMock, :add, fn x, y -> x + y end)

      message = ~r"expected OldCalcMock.add/2 to be invoked 2 times but it was invoked once"
      assert_raise Old.Ersatz.VerificationError, message, &verify!/0
    end

    test "verifies all mocks for current process in global mode" do
      set_ersatz_global()

      verify!(OldCalcMock)
      expect(OldCalcMock, :add, fn x, y -> x + y end)

      message = ~r"expected OldCalcMock.add/2 to be invoked once but it was invoked 0 times"
      assert_raise Old.Ersatz.VerificationError, message, &verify!/0

      task =
        Task.async(fn ->
          assert OldCalcMock.add(2, 3) == 5
        end)

      Task.await(task)

      verify!(OldCalcMock)
      expect(OldCalcMock, :add, fn x, y -> x + y end)

      message = ~r"expected OldCalcMock.add/2 to be invoked 2 times but it was invoked once"
      assert_raise Old.Ersatz.VerificationError, message, &verify!/0
    end

    test "raises if a non-mock is given" do
      assert_raise ArgumentError, ~r"module Unknown is not available", fn ->
        verify!(Unknown)
      end

      assert_raise ArgumentError, ~r"module String is not a mock", fn ->
        verify!(String)
      end
    end
  end

  describe "verify_on_exit!/0" do
    setup :verify_on_exit!

    test "verifies all mocks even if none is used in private mode" do
      set_ersatz_private()
      :ok
    end

    test "verifies all mocks for the current process on exit in private mode" do
      set_ersatz_private()

      expect(OldCalcMock, :add, fn x, y -> x + y end)
      assert OldCalcMock.add(2, 3) == 5
    end

    test "verifies all mocks for the current process on exit with previous verification in private mode" do
      set_ersatz_private()

      verify!()
      expect(OldCalcMock, :add, fn x, y -> x + y end)
      assert OldCalcMock.add(2, 3) == 5
    end

    test "verifies all mocks even if none is used in global mode" do
      set_ersatz_global()
      :ok
    end

    test "verifies all mocks for current process on exit in global mode" do
      set_ersatz_global()

      expect(OldCalcMock, :add, fn x, y -> x + y end)

      task =
        Task.async(fn ->
          assert OldCalcMock.add(2, 3) == 5
        end)

      Task.await(task)
    end

    test "verifies all mocks for the current process on exit with previous verification in global mode" do
      set_ersatz_global()

      verify!()
      expect(OldCalcMock, :add, fn x, y -> x + y end)

      task =
        Task.async(fn ->
          assert OldCalcMock.add(2, 3) == 5
        end)

      Task.await(task)
    end
  end

  describe "stub/3" do
    test "allows repeated invocations" do
      in_all_modes(fn ->
        stub(OldCalcMock, :add, fn x, y -> x + y end)
        assert OldCalcMock.add(1, 2) == 3
        assert OldCalcMock.add(3, 4) == 7
      end)
    end

    test "does not fail verification if not called" do
      in_all_modes(fn ->
        stub(OldCalcMock, :add, fn x, y -> x + y end)
        verify!()
      end)
    end

    test "gives expected calls precedence" do
      in_all_modes(fn ->
        OldCalcMock
        |> stub(:add, fn x, y -> x + y end)
        |> expect(:add, fn _, _ -> :expected end)

        assert OldCalcMock.add(1, 1) == :expected
        verify!()
      end)
    end

    test "invokes stub after expectations are fulfilled" do
      in_all_modes(fn ->
        OldCalcMock
        |> stub(:add, fn _x, _y -> :stub end)
        |> expect(:add, 2, fn _, _ -> :expected end)

        assert OldCalcMock.add(1, 1) == :expected
        assert OldCalcMock.add(1, 1) == :expected
        assert OldCalcMock.add(1, 1) == :stub
        verify!()
      end)
    end

    test "overwrites earlier stubs" do
      in_all_modes(fn ->
        OldCalcMock
        |> stub(:add, fn x, y -> x + y end)
        |> stub(:add, fn _x, _y -> 42 end)

        assert OldCalcMock.add(1, 1) == 42
      end)
    end

    test "works with multiple behaviours" do
      in_all_modes(fn ->
        OldSciCalcMock
        |> stub(:add, fn x, y -> x + y end)
        |> stub(:exponent, fn x, y -> :math.pow(x, y) end)

        assert OldSciCalcMock.add(1, 1) == 2
        assert OldSciCalcMock.exponent(2, 3) == 8
      end)
    end

    test "raises if a non-mock is given" do
      in_all_modes(fn ->
        assert_raise ArgumentError, ~r"module Unknown is not available", fn ->
          stub(Unknown, :add, fn x, y -> x + y end)
        end

        assert_raise ArgumentError, ~r"module String is not a mock", fn ->
          stub(String, :add, fn x, y -> x + y end)
        end
      end)
    end

    test "raises if function is not in behaviour" do
      in_all_modes(fn ->
        assert_raise ArgumentError, ~r"unknown function oops/2 for mock OldCalcMock", fn ->
          stub(OldCalcMock, :oops, fn x, y -> x + y end)
        end

        assert_raise ArgumentError, ~r"unknown function add/3 for mock OldCalcMock", fn ->
          stub(OldCalcMock, :add, fn x, y, z -> x + y + z end)
        end
      end)
    end
  end

  describe "stub_with/2" do
    defmodule CalcImplementation do
      @behaviour Calculator
      def add(x, y), do: x + y
      def mult(x, y), do: x * y
    end

    defmodule SciCalcImplementation do
      @behaviour Calculator
      def add(x, y), do: x + y
      def mult(x, y), do: x * y

      @behaviour ScientificCalculator
      def exponent(x, y), do: :math.pow(x, y)
    end

    test "can override stubs" do
      in_all_modes(fn ->
        stub_with(OldCalcMock, CalcImplementation)
        |> expect(:add, fn 1, 2 -> 4 end)

        assert OldCalcMock.add(1, 2) == 4
        verify!()
      end)
    end

    test "stubs all functions with functions from a module" do
      in_all_modes(fn ->
        stub_with(OldCalcMock, CalcImplementation)
        assert OldCalcMock.add(1, 2) == 3
        assert OldCalcMock.add(3, 4) == 7
        assert OldCalcMock.mult(2, 2) == 4
        assert OldCalcMock.mult(3, 4) == 12
      end)
    end

    test "Leaves behaviours not implemented by the module un-stubbed" do
      in_all_modes(fn ->
        stub_with(OldSciCalcMock, CalcImplementation)
        assert OldSciCalcMock.add(1, 2) == 3
        assert OldSciCalcMock.mult(3, 4) == 12

        assert_raise Old.Ersatz.UnexpectedCallError, fn ->
          OldSciCalcMock.exponent(2, 10)
        end
      end)
    end

    test "can stub multiple behaviours from a single module" do
      in_all_modes(fn ->
        stub_with(OldSciCalcMock, SciCalcImplementation)
        assert OldSciCalcMock.add(1, 2) == 3
        assert OldSciCalcMock.mult(3, 4) == 12
        assert OldSciCalcMock.exponent(2, 10) == 1024
      end)
    end
  end

  describe "allow/3" do
    setup :set_ersatz_private
    setup :verify_on_exit!

    test "allows different processes to share mocks from parent process" do
      parent_pid = self()

      {:ok, child_pid} =
        start_link_no_callers(fn ->
          assert_raise Old.Ersatz.UnexpectedCallError, fn -> OldCalcMock.add(1, 1) end

          receive do
            :call_mock ->
              add_result = OldCalcMock.add(1, 1)
              mult_result = OldCalcMock.mult(1, 1)
              send(parent_pid, {:verify, add_result, mult_result})
          end
        end)

      OldCalcMock
      |> expect(:add, fn _, _ -> :expected end)
      |> stub(:mult, fn _, _ -> :stubbed end)
      |> allow(self(), child_pid)

      send(child_pid, :call_mock)

      assert_receive {:verify, add_result, mult_result}
      assert add_result == :expected
      assert mult_result == :stubbed
    end

    test "allows different processes to share mocks from child process" do
      parent_pid = self()

      OldCalcMock
      |> expect(:add, fn _, _ -> :expected end)
      |> stub(:mult, fn _, _ -> :stubbed end)

      async_no_callers(fn ->
        assert_raise Old.Ersatz.UnexpectedCallError, fn -> OldCalcMock.add(1, 1) end

        OldCalcMock
        |> allow(parent_pid, self())

        assert OldCalcMock.add(1, 1) == :expected
        assert OldCalcMock.mult(1, 1) == :stubbed
      end)
      |> Task.await()
    end

    test "allowances are transitive" do
      parent_pid = self()

      {:ok, child_pid} =
        start_link_no_callers(fn ->
          assert_raise(Old.Ersatz.UnexpectedCallError, fn -> OldCalcMock.add(1, 1) end)

          receive do
            :call_mock ->
              add_result = OldCalcMock.add(1, 1)
              mult_result = OldCalcMock.mult(1, 1)
              send(parent_pid, {:verify, add_result, mult_result})
          end
        end)

      {:ok, transitive_pid} =
        Task.start_link(fn ->
          receive do
            :allow_mock ->
              OldCalcMock
              |> allow(self(), child_pid)

              send(child_pid, :call_mock)
          end
        end)

      OldCalcMock
      |> expect(:add, fn _, _ -> :expected end)
      |> stub(:mult, fn _, _ -> :stubbed end)
      |> allow(self(), transitive_pid)

      send(transitive_pid, :allow_mock)

      receive do
        {:verify, add_result, mult_result} ->
          assert add_result == :expected
          assert mult_result == :stubbed
          verify!()
      after
        1000 -> verify!()
      end
    end

    test "allowances are reclaimed if the owner process dies" do
      parent_pid = self()

      task =
        Task.async(fn ->
          OldCalcMock
          |> expect(:add, fn _, _ -> :expected end)
          |> stub(:mult, fn _, _ -> :stubbed end)
          |> allow(self(), parent_pid)
        end)

      Task.await(task)

      assert_raise Old.Ersatz.UnexpectedCallError, fn ->
        OldCalcMock.add(1, 1)
      end

      OldCalcMock
      |> expect(:add, 1, fn x, y -> x + y end)

      assert OldCalcMock.add(1, 1) == 2
    end

    test "allowances support locally registered processes" do
      parent_pid = self()
      process_name = :test_process

      {:ok, child_pid} =
        Task.start_link(fn ->
          receive do
            :call_mock ->
              add_result = OldCalcMock.add(1, 1)
              send(parent_pid, {:verify, add_result})
          end
        end)

      Process.register(child_pid, process_name)

      OldCalcMock
      |> expect(:add, fn _, _ -> :expected end)
      |> allow(self(), process_name)

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
          add_result = OldCalcMock.add(1, 1)
          {:reply, add_result, []}
        end
      end

      {:ok, _} = Registry.start_link(keys: :unique, name: Registry.Test)
      name = {:via, Registry, {Registry.Test, :test_process}}
      {:ok, _} = GenServer.start_link(CalculatorServer, [], name: name)

      OldCalcMock
      |> expect(:add, fn _, _ -> :expected end)
      |> allow(self(), name)

      add_result = GenServer.call(name, :call_mock)
      assert add_result == :expected
    end

    test "raises if you try to allow itself" do
      assert_raise ArgumentError, "owner_pid and allowed_pid must be different", fn ->
        OldCalcMock
        |> allow(self(), self())
      end
    end

    test "raises if you try to allow already allowed process" do
      {:ok, child_pid} = Task.start_link(fn -> Process.sleep(:infinity) end)

      OldCalcMock
      |> allow(self(), child_pid)
      |> allow(self(), child_pid)

      Task.async(fn ->
        assert_raise ArgumentError, ~r"it is already allowed by", fn ->
          OldCalcMock
          |> allow(self(), child_pid)
        end
      end)
      |> Task.await()
    end

    test "raises if you try to allow process with existing expectations set" do
      parent_pid = self()

      {:ok, pid} =
        Task.start_link(fn ->
          OldCalcMock
          |> expect(:add, fn _, _ -> :expected end)

          send(parent_pid, :ready)
          Process.sleep(:infinity)
        end)

      assert_receive :ready

      assert_raise ArgumentError, ~r"the process has already defined its own expectations", fn ->
        OldCalcMock
        |> allow(self(), pid)
      end
    end

    test "raises if you try to define expectations on allowed process" do
      parent_pid = self()

      Task.start_link(fn ->
        OldCalcMock
        |> allow(self(), parent_pid)

        send(parent_pid, :ready)
        Process.sleep(:infinity)
      end)

      assert_receive :ready

      assert_raise ArgumentError, ~r"because the process has been allowed by", fn ->
        OldCalcMock
        |> expect(:add, fn _, _ -> :expected end)
      end
    end

    test "is ignored if you allow process while in global mode" do
      set_ersatz_global()
      {:ok, child_pid} = Task.start_link(fn -> Process.sleep(:infinity) end)

      Task.async(fn ->
        mock = OldCalcMock
        assert allow(mock, self(), child_pid) == mock
      end)
      |> Task.await()
    end
  end

  defp async_no_callers(fun) do
    Task.async(fn ->
      Process.delete(:"$callers")
      fun.()
    end)
  end

  defp start_link_no_callers(fun) do
    Task.start_link(fn ->
      Process.delete(:"$callers")
      fun.()
    end)
  end
end