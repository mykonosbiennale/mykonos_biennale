defmodule MykonosBiennaleWeb.Admin.SEOSection do
  @moduledoc """
  The SEO block shown in every entity admin form.

  Fields are pre-filled from the entity: the stored override when there is one,
  otherwise the automatic value derived from the entity's fields. Submitted values
  are passed through `MykonosBiennale.SEO.overrides_from_params/2` before saving.
  """

  use Phoenix.Component

  require Logger

  alias MykonosBiennale.Content
  alias MykonosBiennale.SEO

  @input_class "w-full bg-neutral-900 border border-gray-700 px-3 py-2 text-white"

  @doc """
  Saves the submitted SEO overrides onto `saved`. `before` is the entity as it was
  when the form opened (nil on create), so the automatic defaults match what the
  editor saw. Blank or default values are not stored.
  """
  def persist(before, saved, seo_params) do
    overrides = SEO.overrides_from_params(seo_params, SEO.defaults(before))

    case Content.put_seo(saved, overrides) do
      {:ok, _} ->
        :ok

      {:error, reason} ->
        Logger.warning("SEO save failed for entity #{saved.id}: #{inspect(reason)}")
        :error
    end
  end

  attr :entity, :any, default: nil, doc: "The entity being edited, or nil for a new one"

  def fields(assigns) do
    defaults = SEO.defaults(assigns.entity)
    overrides = SEO.overrides(assigns.entity)

    assigns =
      assigns
      |> assign(:defaults, defaults)
      |> assign(:title, overrides["title"] || defaults.title)
      |> assign(:description, overrides["description"] || defaults.description)
      |> assign(:noindex, overrides["noindex"] == true)
      |> assign(:input_class, @input_class)

    ~H"""
    <fieldset id="seo-section" class="border border-gray-700 p-4 space-y-3">
      <legend class="px-2 text-sm font-semibold uppercase tracking-wider">SEO</legend>
      <p class="text-xs text-gray-400">
        Filled from this entity's fields. Change a value to override it; clear it to go back to the automatic value.
      </p>

      <label class="block space-y-1">
        <span class="text-sm">Title</span>
        <input type="text" name="seo[title]" value={@title} class={@input_class} />
      </label>

      <label class="block space-y-1">
        <span class="text-sm">Description</span>
        <textarea name="seo[description]" rows="3" class={@input_class}>{@description}</textarea>
      </label>

      <label class="flex items-center gap-2 text-sm">
        <input type="checkbox" name="seo[noindex]" value="true" checked={@noindex} />
        Hide from search engines
      </label>
    </fieldset>
    """
  end
end
