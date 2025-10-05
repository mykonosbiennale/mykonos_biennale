defmodule MykonosBiennaleWeb.Filters.PageSelect do
  @moduledoc """
  Implementation of the `Backpex.Filters.MultiSelect` behaviour.
  """

  use Backpex.Filters.Select

  alias MykonosBiennale.Site.Page
  alias MykonosBiennale.Site.Section
  alias MykonosBiennale.Repo

  @impl Backpex.Filter
  def label, do: "Page"

  @impl Backpex.Filters.Select
  def prompt, do: "Select page ..."

  @impl Backpex.Filters.Select
  def options(_assigns) do
    query =
      from s in Section,
        join: p in Page,
        on: s.page_id == p.id,
        distinct: p.title,
        select: {p.title, p.id}

    Repo.all(query)
  end
end
