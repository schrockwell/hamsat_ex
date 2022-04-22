defmodule Hamsat.Context do
  defstruct [:user, :observer]

  def get_observer(%{user: nil, observer: nil}), do: nil
  def get_observer(%{user: nil, observer: observer}), do: observer
end