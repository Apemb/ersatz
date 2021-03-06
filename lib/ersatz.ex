defmodule Ersatz do
  @moduledoc """
  Ersatz is a library for defining mocks in Elixir.

  -   Mocks are generated based on behaviours during configuration and injected using env variables.
  -   Add the mock behaviour by specifying functions to be used during tests with `Ersatz.set_mock_implementation/3` or
  `Ersatz.set_mock_return_value/3`.
  -   Test your code's actions on the mock dependency using `Ersatz.get_mock_calls/1` or the Espec custom matchers.

  ## Example

  As an example, imagine that your library defines a calculator behaviour:

      defmodule MyApp.Calculator do
        @callback add(integer(), integer()) :: integer()
        @callback mult(integer(), integer()) :: integer()
      end

  If you want to mock the calculator behaviour during tests, the first step
  is to define the mock, usually in your `test_helper.exs`:

      Ersatz.defmock(MyApp.CalcMock, for: MyApp.Calculator)

  Now in your tests, you can define mock implementations and verify that they were called the right number of times
  and with the right parameters:

      use ExUnit.Case, async: true

      import Ersatz

      test "invokes add and mult" do
        # Arrange
        Ersatz.set_mock_implementation(&MyApp.CalcMock.add/2, fn x, y -> x + y end)
        Ersatz.set_mock_return_value(&MyApp.CalcMock.mult/2, 42)

        # Act
        add_result = MyApp.CalcMock.add(2, 3)
        mult_result = MyApp.CalcMock.mult(4, 1)

        # Assert
        assert add_result == 5 # assert the result is the one we expected
        assert mult_result == 42 # assert the result is the one we expected

        add_mock_calls = Ersatz.get_mock_calls(&MyApp.CalcMock.add/2) # get the calls our mock implementation received
        assert add_mock_calls == [[2, 3]] # assert the call args are the ones we expected
        mult_mock_calls = Ersatz.get_mock_calls(&MyApp.CalcMock.mult/2) # get the calls our mock implementation received
        assert mult_mock_calls == [[4, 1]] # assert the call args are the ones we expected
      end

  In practice, you will have to pass the mock to the system under the test.
  If the system under test relies on application configuration, you should
  also set it before the tests starts to keep the async property. Usually
  in your config files:

      config :my_app, :calculator, MyApp.CalcMock

  Or in your `test_helper.exs`:

      Application.put_env(:my_app, :calculator, MyApp.CalcMock)

  All expectations are defined based on the current process. This
  means multiple tests using the same mock can still run concurrently
  unless the Ersatz is set to global mode. See the "Multi-process collaboration"
  section.

  ## Multiple behaviours

  Ersatz supports defining mocks for multiple behaviours.

  Suppose your library also defines a scientific calculator behaviour:

      defmodule MyApp.ScientificCalculator do
        @callback exponent(integer(), integer()) :: integer()
      end

  You can mock both the calculator and scientific calculator behaviour:

      Ersatz.defmock(MyApp.SciCalcMock, for: [MyApp.Calculator, MyApp.ScientificCalculator])

  ## Compile-time requirements

  If the mock needs to be available during the project compilation, for
  instance because you get undefined function warnings, then instead of
  defining the mock in your `test_helper.exs`, you should instead define
  it under `test/support/mocks.ex`:

      Ersatz.defmock(MyApp.CalcMock, for: MyApp.Calculator)

  Then you need to make sure that files in `test/support` get compiled
  with the rest of the project. Edit your `mix.exs` file to add the
  `test/support` directory to compilation paths:

      def project do
        [
          ...
          elixirc_paths: elixirc_paths(Mix.env),
          ...
        ]
      end

      defp elixirc_paths(:test), do: ["test/support", "lib"]
      defp elixirc_paths(_),     do: ["lib"]

  ## Multi-process collaboration

  Ersatz supports multi-process collaboration via two mechanisms:

    1. explicit allowances
    2. global mode

  The allowance mechanism can still run tests concurrently while
  the global one doesn't. We explore both next.

  ### Explicit allowances

  An allowance permits a child process to use the expectations and stubs
  defined in the parent process while still being safe for async tests.

      test "invokes add and mult from a task" do
        Ersatz.set_mock_implementation(&MyApp.CalcMock.add/2, fn x, y -> x + y end)
        Ersatz.set_mock_return_value(&MyApp.CalcMock.mult/2, 42)

        parent_pid = self()

        Task.async(fn ->
          MyApp.CalcMock |> allow(parent_pid, self())
          assert MyApp.CalcMock.add(2, 3) == 5
          assert MyApp.CalcMock.mult(2, 3) == 6
        end)
        |> Task.await
      end

  Note: if you're running on Elixir 1.8.0 or greater and your concurrency comes
  from a `Task` then you don't need to add explicit allowances. Instead
  `$callers` is used to determine the process that actually defined the
  expectations.

  ### Global mode

  Ersatz supports global mode, where any process can consume mocks and stubs
  defined in your tests. To manually switch to global mode use:

      set_ersatz_global()

      test "invokes add and mult from a task" do
        Ersatz.set_mock_implementation(&MyApp.CalcMock.add/2, fn x, y -> x + y end)
        Ersatz.set_mock_return_value(&MyApp.CalcMock.mult/2, 42)

        Task.async(fn ->
          assert MyApp.CalcMock.add(2, 3) == 5
          assert MyApp.CalcMock.mult(2, 3) == 42
        end)
        |> Task.await
      end

  The global mode must always be explicitly set per test. By default
  mocks run on `private` mode.

  You can also automatically choose global or private mode depending on
  if your tests run in async mode or not. In such case Ersatz will use
  private mode when `async: true`, global mode otherwise:

      setup :set_ersatz_from_context

  """

  defmodule UnexpectedCallError do
    defexception [:message]
  end

  defmodule VerificationError do
    defexception [:message]
  end

  @doc """
  Sets the Ersatz to private mode, where mocks can be set and
  consumed by the same process unless other processes are
  explicitly allowed.

      setup :set_ersatz_private

  """
  def set_ersatz_private(_context \\ %{}), do: Ersatz.Server.set_mode(self(), :private)

  @doc """
  Sets the Ersatz to global mode, where mocks can be consumed
  by any process.

      setup :set_ersatz_global

  """
  def set_ersatz_global(_context \\ %{}), do: Ersatz.Server.set_mode(self(), :global)

  @doc """
  Chooses the Ersatz mode based on context. When `async: true` is used
  the mode is `:private`, otherwise `:global` is chosen.

      setup :set_ersatz_from_context

  """
  def set_ersatz_from_context(%{async: true} = _context), do: set_ersatz_private()
  def set_ersatz_from_context(_context), do: set_ersatz_global()

  @doc """
  Defines a mock with the given name `:for` the given behaviour(s).

      Ersatz.defmock(MyMock, for: MyBehaviour)

  With multiple behaviours:

      Ersatz.defmock(MyMock, for: [MyBehaviour, MyOtherBehaviour])

  ## Skipping optional callbacks

  By default, functions are created for all callbacks, including all optional
  callbacks. But if for some reason you want to skip optional callbacks, you can
  provide the list of callback names to skip (along with their arities) as
  `:skip_optional_callbacks`:

      Ersatz.defmock(MyMock, for: MyBehaviour, skip_optional_callbacks: [on_success: 2])

  This will define a new mock (`MyMock`) that has a defined function for each
  callback on `MyBehaviour` except for `on_success/2`. Note: you can only skip
  optional callbacks, not required callbacks.

  You can also pass `true` to skip all optional callbacks, or `false` to keep
  the default of generating functions for all optional callbacks.
  """
  def defmock(name, options) when is_atom(name) and is_list(options) do
    behaviours =
      case Keyword.fetch(options, :for) do
        {:ok, mocks} -> List.wrap(mocks)
        :error -> raise ArgumentError, ":for option is required on defmock"
      end

    skip_optional_callbacks = Keyword.get(options, :skip_optional_callbacks, [])

    compile_header = generate_compile_time_dependency(behaviours)
    callbacks_to_skip = validate_skip_optional_callbacks!(behaviours, skip_optional_callbacks)
    mock_funs = generate_mock_funs(behaviours, callbacks_to_skip)
    define_mock_module(name, behaviours, compile_header ++ mock_funs)
    name
  end

  defp validate_behaviour!(behaviour) do
    cond do
      not Code.ensure_compiled?(behaviour) ->
        raise ArgumentError,
              "module #{inspect(behaviour)} is not available, please pass an existing module to :for"

      not function_exported?(behaviour, :behaviour_info, 1) ->
        raise ArgumentError,
              "module #{inspect(behaviour)} is not a behaviour, please pass a behaviour to :for"

      true ->
        behaviour
    end
  end

  defp generate_compile_time_dependency(behaviours) do
    for behaviour <- behaviours do
      validate_behaviour!(behaviour)

      quote do
        unquote(behaviour).module_info(:module)
      end
    end
  end

  defp generate_mock_funs(behaviours, callbacks_to_skip) do
    for behaviour <- behaviours,
        {fun, arity} <- behaviour.behaviour_info(:callbacks),
        {fun, arity} not in callbacks_to_skip do
      args = 0..arity
             |> Enum.to_list()
             |> tl()
             |> Enum.map(&Macro.var(:"arg#{&1}", Elixir))

      quote do
        def unquote(fun)(unquote_splicing(args)) do
          Ersatz.__dispatch__(__MODULE__, unquote(fun), unquote(arity), unquote(args))
        end
      end
    end
  end

  defp validate_skip_optional_callbacks!(behaviours, skip_optional_callbacks) do
    all_optional_callbacks =
      for behaviour <- behaviours,
          {fun, arity} <- behaviour.behaviour_info(:optional_callbacks) do
        {fun, arity}
      end

    case skip_optional_callbacks do
      false ->
        []

      true ->
        all_optional_callbacks

      skip_list when is_list(skip_list) ->
        for callback <- skip_optional_callbacks, callback not in all_optional_callbacks do
          raise ArgumentError,
                "all entries in :skip_optional_callbacks must be an optional callback in one " <>
                "of the behaviours specified in :for. #{inspect(callback)} was not in the " <>
                "list of all optional callbacks: #{inspect(all_optional_callbacks)}"
        end

        skip_list

      _ ->
        raise ArgumentError, ":skip_optional_callbacks is required to be a list or boolean"
    end
  end

  defp define_mock_module(name, behaviours, body) do
    info =
      quote do
        def __mock_for__ do
          unquote(behaviours)
        end
      end

    Module.create(name, [info | body], Macro.Env.location(__ENV__))
  end

  @doc """
  Specify the function to be used as mock. It can be a limited in use mock implementation or a permanent mock that does
  not wear down (defaults to permanent mock).

  Note that only one permanent mock implementation is possible at the same time but multiple time limited implementation
  are possible (used in the same order they were added). If a permanent and (multiple) temporary mock(s) implementations
  are defined, the temporary mock implementations are used before the permanent one.

  If no mock implementation is available and the mock is nevertheless called, an error is raised.

  ## Options
    - `times:` to specify the number of usage that are allowed for that mock implementation. If it is an integer the
    mock implementation will be limited to that number of usages. If it is set to `times: :permanent` the mock
    implementation will be ok for an unlimited number of uses.

  ## Example
  ```
  # For a permanent mock implementation
  Ersatz.set_mock_implementation(&MockCalc.add/2, fn x, y -> x + y)
  Ersatz.set_mock_implementation(&MockCalc.add/2, fn x, y -> x + y, times: :permanent)

  # For a mock implementation limited to 2 usages
  Ersatz.set_mock_implementation(&MockCalc.add/2, fn x, y -> x + y, times: 2)
  ```
  """
  def set_mock_implementation(function_to_mock, mock_function, options \\ [])
      when is_function(function_to_mock) and is_function(mock_function) do

    number_of_usages = Access.get(options, :times, :permanent)

    {:module, mock_module} = Function.info(function_to_mock, :module)
    {:name, function_name} = Function.info(function_to_mock, :name)
    {:arity, arity} = Function.info(function_to_mock, :arity)

    return_object = Ersatz.ReturnObject.create_from_function(mock_function)

    validate_mock_module!(mock_module)
    validate_function!(function_to_mock)

    replacement_function_arity = :erlang.fun_info(mock_function)[:arity]
    unless arity == replacement_function_arity do
      raise ArgumentError, "replacement function and #{function_name}/#{arity} do not have same arity"
    end

    case number_of_usages do
      :permanent ->
        add_return_object!(mock_module, function_name, arity, {0, [], return_object})

      number_of_usages when is_integer(number_of_usages) and number_of_usages >= 0 ->
        calls = List.duplicate(return_object, number_of_usages)
        add_return_object!(mock_module, function_name, arity, {number_of_usages, calls, nil})
    end

    function_to_mock
  end

  @doc """
  Specify the return value to be used as response of the function that is going to be replaced.
  It can be a limited in use or a permanent response that does not wear down (defaults to permanent response).

  It is a simpler way to give a mock implementation to your mock modules compared to the `set_mock_implementation/3`
  function.

  Note that only one permanent response or mock function implementation is possible at the same time but multiple time
  limited implementation are possible (used in the same order they were added). If a permanent and (multiple) temporary mock(s)
  implementations are defined, the temporary mock implementations are used before the permanent one.

  If no mock implementation is available and the mock is nevertheless called, an error is raised.

  `set_mock_return_value/3` and `set_mock_implementation/3` react on the same way. `set_mock_return_value/3` is a type
  of mock implementation. So expect the same behaviour for permanent mock implementation (only one at the same time), or
  for order of the temporary mock implementations.

  ## Options
    - `times:` to specify the number of usage that are allowed for that mock implementation. If it is an integer the
    mock implementation will be limited to that number of usages. If it is set to `times: :permanent` the mock
    implementation will be ok for an unlimited number of uses.

  ## Example
  ```
  # For a permanent mock implementation defined by a return value
  Ersatz.set_mock_return_value(&MockCalc.add/2, 4)
  Ersatz.set_mock_return_value(&MockCalc.add/2, 4, times: :permanent)

  # For a mock implementation defined by a return value limited to 2 usages
  Ersatz.set_mock_return_value(&MockCalc.add/2, 4, times: 2)
  ```
  """
  def set_mock_return_value(function_to_mock, return_value, options \\ [])
      when is_function(function_to_mock) do

    number_of_usages = Access.get(options, :times, :permanent)

    {:module, mock_module} = Function.info(function_to_mock, :module)
    {:name, function_name} = Function.info(function_to_mock, :name)
    {:arity, arity} = Function.info(function_to_mock, :arity)

    return_object = Ersatz.ReturnObject.create_from_return_value(return_value)

    validate_mock_module!(mock_module)
    validate_function!(function_to_mock)

    case number_of_usages do
      :permanent ->
        add_return_object!(mock_module, function_name, arity, {0, [], return_object})

      number_of_usages when is_integer(number_of_usages) and number_of_usages >= 0 ->
        calls = List.duplicate(return_object, number_of_usages)
        add_return_object!(mock_module, function_name, arity, {number_of_usages, calls, nil})
    end

    function_to_mock
  end

  defp add_return_object!(mock, name, arity, value) do

    key = {mock, name, arity}

    case Ersatz.Server.add_return_object(self(), key, value) do
      :ok ->
        :ok

      {:error, {:currently_allowed, owner_pid}} ->
        inspected = inspect(self())

        raise ArgumentError,
              "cannot add expectations/stubs to #{inspect(mock)} in the current process (#{inspected})" <>
              "because the process has been allowed by #{ inspect(owner_pid) }." <>
              "You cannot define expectations/stubs in a process that has been allowed."

      {:error, {:not_global_owner, global_pid}} ->
        inspected = inspect(self())

        raise ArgumentError,
              "cannot add expectations/stubs to #{inspect(mock)} in the current process (#{inspected}) " <>
              "because Ersatz is in global mode and the global process is #{inspect(global_pid)}. " <>
              "Only the process that set Ersatz to global can set expectations/stubs in global mode."
    end
  end

  defp validate_mock_module!(mock_module) do
    cond do
      not Code.ensure_compiled?(mock_module) ->
        raise ArgumentError, "module #{inspect(mock_module)} is not available"

      not function_exported?(mock_module, :__mock_for__, 0) ->
        raise ArgumentError, "module #{inspect(mock_module)} is not a mock"

      true ->
        :ok
    end
  end

  defp validate_function!(function_to_mock) do
    {:module, mock_module} = Function.info(function_to_mock, :module)
    {:name, function_name} = Function.info(function_to_mock, :name)
    {:arity, arity} = Function.info(function_to_mock, :arity)

    cond do
      not function_exported?(mock_module, function_name, arity) ->
        raise ArgumentError, "unknown function #{function_name}/#{arity} for mock #{inspect(mock_module)}"

      true ->
        :ok
    end
  end

  @doc """
  Get the calls arguments that were used to call the mock function.

  ## Example
  ```
  # For a mock implementation that was called twice once with 2, 2 and the second time with 3, 4
  Ersatz.get_mock_calls(&MockCalc.add/2) # [[2, 2], [3, 4]]
  ```
  """
  def get_mock_calls(mocked_function) when is_function(mocked_function) do
    all_callers = [self() | caller_pids()]

    {:module, mock_module} = Function.info(mocked_function, :module)
    {:name, function_name} = Function.info(mocked_function, :name)
    {:arity, arity} = Function.info(mocked_function, :arity)

    validate_mock_module!(mock_module)
    validate_function!(mocked_function)

    case Ersatz.Server.fetch_fun_calls(all_callers, {mock_module, function_name, arity}) do
      {:ok, calls} when is_list(calls) ->
        calls
      {:ok, nil} ->
        # TODO: useful error message
        raise UnexpectedCallError, "todo error on get mock calls (arg {:ok, nil})"
      arg ->
        # TODO: useful error message
        raise UnexpectedCallError, "todo error on get mock calls (arg #{arg})"
    end
  end

  @doc """
  Resets the calls to that mock function. Useful in case of permanent mock implementations shared between multiple
  tests (using a setup block for example)

  ## Example

      Ersatz.clear_mock_calls(&MockCalc.add/2)

  """
  def clear_mock_calls(mocked_function) when is_function(mocked_function) do
    all_callers = [self() | caller_pids()]

    {:module, mock_module} = Function.info(mocked_function, :module)
    {:name, function_name} = Function.info(mocked_function, :name)
    {:arity, arity} = Function.info(mocked_function, :arity)

    validate_mock_module!(mock_module)
    validate_function!(mocked_function)

    case Ersatz.Server.clear_mock_calls(all_callers, {mock_module, function_name, arity}) do
      :ok -> :ok
      {:error, reason} ->
        # TODO: useful error message
        raise UnexpectedCallError, "todo error on clear mocks call #{reason}"
    end
  end

  @doc """
  Allows other processes to share expectations and stubs
  defined by owner process.

  ## Examples

  To allow `child_pid` to call any stubs or expectations defined for mock module `CalcMock`:

      Ersatz.allow(CalcMock, self(), child_pid)

  `allow/3` also accepts named process or via references:

      Ersatz.allow(CalcMock, self(), SomeChildProcess)

  """
  def allow(mock_module, owner_pid, allowed_via) when is_atom(mock_module) and is_pid(owner_pid)  do
    allowed_pid = GenServer.whereis(allowed_via)

    if allowed_pid == owner_pid do
      raise ArgumentError, "owner_pid and allowed_pid must be different"
    end

    case Ersatz.Server.allow(mock_module, owner_pid, allowed_pid) do
      :ok ->
        mock_module

      {:error, {:already_allowed, actual_pid}} ->
        raise ArgumentError, """
        cannot allow #{inspect(allowed_pid)} to use #{inspect(mock_module)} from #{inspect(owner_pid)} \
                                because it is already allowed by #{inspect(actual_pid)}.

        If you are seeing this error message, it is because you are either \
                                setting up allowances from different processes or your tests have \
                                async: true and you found a race condition where two different tests \
                                are allowing the same process
        """

      {:error, :expectations_defined} ->
        raise ArgumentError, """
        cannot allow #{inspect(allowed_pid)} to use #{inspect(mock_module)} from #{inspect(owner_pid)} \
                                because the process has already defined its own expectations/stubs
        """

      {:error, :in_global_mode} ->
        # Already allowed
        mock_module
    end
  end

  @doc false
  def __dispatch__(mock, name, arity, args) do
    all_callers = [self() | caller_pids()]

    case Ersatz.Server.fetch_return_object_to_dispatch(all_callers, {mock, name, arity}, args) do
      :no_expectation ->
        mfa = Exception.format_mfa(mock, name, arity)

        raise UnexpectedCallError,
              "no implementation defined for #{mfa} in #{format_process()} (with args #{inspect(args)})"

      {:out_of_expectations, count} ->
        mfa = Exception.format_mfa(mock, name, arity)

        raise UnexpectedCallError, "expected #{mfa} to be called #{times(count)} but it has been " <>
                                   "called #{times(count + 1)} in process #{format_process()}"

      {:ok, return_object} ->
        Ersatz.ReturnObject.define_return_value(return_object, args)
    end
  end

  defp times(1), do: "once"
  defp times(n), do: "#{n} times"

  defp format_process do
    callers = caller_pids()

    "process #{inspect(self())}" <>
    if Enum.empty?(callers) do
      ""
    else
      " (or in its callers #{inspect(callers)})"
    end
  end

  # Find the pid of the actual caller
  defp caller_pids do
    case Process.get(:"$callers") do
      nil -> []
      pids when is_list(pids) -> pids
    end
  end
end
