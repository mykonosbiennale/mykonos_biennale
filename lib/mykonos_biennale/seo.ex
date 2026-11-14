defmodule MykonosBiennale.SEO do
  @moduledoc """
  Search and social metadata for an entity.

  `defaults/1` derives the title and description from the entity's current fields.
  Only overrides are stored, in `entities.seo`. A value that matches the derived
  default is not stored, so the page keeps following the entity's fields.
  """

  @film_types ["Short Film", "Video", "Dance", "Animation", "Documentary"]

  @doc "Automatic title and description for an entity. Nil values when unknown."
  def defaults(%{type: "biennale", fields: f}) do
    %{
      title: "Mykonos Biennale #{f["year"]}",
      description: text(f["description"] || f["statement"] || f["theme"])
    }
  end

  def defaults(%{type: "artwork", fields: f}) do
    %{title: text(f["title"]), description: text(f["description"])}
  end

  def defaults(%{type: "event", fields: f}) do
    %{title: text(f["title"]), description: text(f["description"] || f["statement"])}
  end

  def defaults(%{type: "project", fields: f}) do
    %{title: text(f["title"]), description: text(f["description"] || f["statement"])}
  end

  def defaults(%{type: "participant", identity: identity, fields: f}) do
    %{title: text(identity), description: text(f["bio"])}
  end

  def defaults(%{type: type, identity: identity, fields: f}) when type in @film_types do
    %{title: text(identity), description: text(f["synopsis"] || f["log_line"])}
  end

  def defaults(_entity), do: %{title: nil, description: nil}

  @doc "Stored overrides for an entity, as a map with string keys. Empty when none."
  def overrides(%{seo: seo}) when is_map(seo), do: seo
  def overrides(_entity), do: %{}

  @doc """
  Turns submitted `seo` form params into the overrides to store.

  Blank values and values equal to the automatic default are dropped, so
  clearing a field goes back to the automatic value.
  """
  def overrides_from_params(params, defaults) do
    params = params || %{}

    %{}
    |> put_override("title", params["title"], defaults.title)
    |> put_override("description", params["description"], defaults.description)
    |> put_noindex(params["noindex"])
  end

  defp put_override(acc, key, value, default) do
    value = text(value)

    if value && value != text(default) do
      Map.put(acc, key, value)
    else
      acc
    end
  end

  defp put_noindex(acc, value) when value in ["true", true], do: Map.put(acc, "noindex", true)
  defp put_noindex(acc, _value), do: acc

  defp text(nil), do: nil

  defp text(value) when is_binary(value) do
    case String.trim(value) do
      "" -> nil
      trimmed -> trimmed
    end
  end

  defp text(_), do: nil
end
