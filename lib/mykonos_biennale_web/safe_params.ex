defmodule MykonosBiennaleWeb.SafeParams do
  @moduledoc """
  Converts request parameters to atoms without creating new ones.

  `String.to_atom/1` on client input lets anyone grow the atom table until the
  VM runs out of memory, so only atoms that already exist are accepted. Anything
  else falls back to the given default.
  """

  @doc "Returns the sort key as an existing atom, or `default`."
  def sort_key(value, default) when is_binary(value) do
    String.to_existing_atom(value)
  rescue
    ArgumentError -> default
  end

  def sort_key(_value, default), do: default

  @doc "Returns `:asc` or `:desc`, or `default` for anything else."
  def sort_dir(value, _default) when value in ["asc", "desc"],
    do: String.to_existing_atom(value)

  def sort_dir(_value, default), do: default
end
