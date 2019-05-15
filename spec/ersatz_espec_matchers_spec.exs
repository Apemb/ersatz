defmodule ErsatzEspecMatchersSpec do
  use ESpec

  import Ersatz
  import Ersatz.Matchers.ESpec

  defmodule Calculator do
    @callback add(integer(), integer()) :: integer()
    @callback minus(integer(), integer()) :: integer()
    @callback mult(integer(), integer()) :: integer()
  end

  defmock(EspecCalcMock, for: Calculator)

  before do
    Ersatz.set_ersatz_global()
  end

  finally do
    Ersatz.clear_mock_calls(&EspecCalcMock.add/2)
  end

  describe "have_been_called" do

    before do
      Ersatz.set_mock_implementation(&EspecCalcMock.add/2, fn x, y -> x + y end)
    end

    context "mock function never called" do

      it "is false with default option (equivalent to at_least_once)" do
        (&EspecCalcMock.add/2)
        |> should_not(have_been_called())
      end

      it "is false with times: :at_least_once" do
        (&EspecCalcMock.add/2)
        |> should_not(have_been_called(times: :at_least_once))
      end

      it "is true with times: 0" do
        (&EspecCalcMock.add/2)
        |> should(have_been_called(times: 0))
      end
    end

    context "mock function called once" do

      before do
        EspecCalcMock.add(1, 2)
      end

      it "is true with default option (equivalent to at_least_once)" do
        (&EspecCalcMock.add/2)
        |> should(have_been_called())
      end

      it "is true with times: :at_least_once" do
        (&EspecCalcMock.add/2)
        |> should(have_been_called(times: :at_least_once))
      end

      it "is true with times: 1" do
        (&EspecCalcMock.add/2)
        |> should(have_been_called(times: 1))
      end
    end

    context "mock function called tree times" do

      before do
        EspecCalcMock.add(1, 2)
        EspecCalcMock.add(1, 2)
        EspecCalcMock.add(1, 2)
      end

      it "is true with default option (equivalent to at_least_once)" do
        (&EspecCalcMock.add/2)
        |> should(have_been_called())
      end

      it "is true with times: :at_least_once" do
        (&EspecCalcMock.add/2)
        |> should(have_been_called(times: :at_least_once))
      end

      it "is true with times: 3" do
        (&EspecCalcMock.add/2)
        |> should(have_been_called(times: 3))
      end
    end
  end

  describe "have_been_called_with" do

    before do
      Ersatz.set_mock_implementation(&EspecCalcMock.add/2, fn x, y -> x + y end)
    end

    before do
      EspecCalcMock.add(1, 2)
      EspecCalcMock.add(3, 7)
      EspecCalcMock.add(1, 2)
    end

    it "is true with exactly: [{1, 2}, {3, 7}, {1, 2}]" do
      (&EspecCalcMock.add/2)
      |> should(have_been_called_with(exactly: [{1, 2}, {3, 7}, {1, 2}]))
    end

    it "is false with exactly: [{1, 2}, {3, 7}]" do
      (&EspecCalcMock.add/2)
      |> should_not(have_been_called_with(exactly: [{1, 2}, {3, 7}]))
    end

    it "is true with at_least_once: {1, 2}" do
      (&EspecCalcMock.add/2)
      |> should(have_been_called_with(at_least_once: {1, 2}))
    end

    it "is true with at_least_once: {3, 7}" do
      (&EspecCalcMock.add/2)
      |> should(have_been_called_with(at_least_once: {3, 7}))
    end

    it "is false with at_least_once: {1, 1}" do
      (&EspecCalcMock.add/2)
      |> should_not(have_been_called_with(at_least_once: {1, 1}))
    end

    it "is false with at_least_once: {:whatever}" do
      (&EspecCalcMock.add/2)
      |> should_not(have_been_called_with(at_least_once: {:whatever}))
    end
  end
end
