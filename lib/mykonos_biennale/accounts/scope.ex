defmodule MykonosBiennale.Accounts.Scope do
  @moduledoc """
  Defines the scope of the caller to be used throughout the app.
  """

  alias MykonosBiennale.Accounts.User

  defstruct user: nil, role: :participant

  @doc """
  Creates a scope for the given user.
  """
  def for_user(%User{} = user) do
    %__MODULE__{user: user, role: user.role}
  end

  def for_user(nil), do: nil

  def admin?(%__MODULE__{role: :admin}), do: true
  def admin?(_), do: false

  def staff?(%__MODULE__{role: role}) when role in [:admin, :staff], do: true
  def staff?(_), do: false
end