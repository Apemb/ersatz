defmodule Ersatz.ReturnObject do
  @moduledoc false

  defstruct [:type, :value]

  def create_from_function(function), do: %Ersatz.ReturnObject{type: :function, value: function}

  def create_from_return_value(value), do: %Ersatz.ReturnObject{type: :return_value, value: value}

  def define_return_value(%Ersatz.ReturnObject{type: :function, value: function}, args), do: apply(function, args)
  def define_return_value(%Ersatz.ReturnObject{type: :return_value, value: value}, args), do: value
end
