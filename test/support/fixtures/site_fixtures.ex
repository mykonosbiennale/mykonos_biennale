defmodule MykonosBiennale.SiteFixtures do
  @moduledoc """
  Test fixtures for the Site context (Pages and Sections).
  """

  alias MykonosBiennale.Site

  defp to_map(attrs) when is_list(attrs), do: Enum.into(attrs, %{})
  defp to_map(attrs) when is_map(attrs), do: attrs
  defp to_map(_), do: %{}

  def page_fixture(attrs \\ %{}) do
    attrs = to_map(attrs)

    {:ok, page} =
      Site.create_page(%{
        title: Map.get(attrs, "title") || Map.get(attrs, :title, "Test Page"),
        slug: Map.get(attrs, "slug") || Map.get(attrs, :slug, "test-page-#{System.unique_integer()}"),
        content: Map.get(attrs, "content") || Map.get(attrs, :content, "<p>Test content</p>"),
        visible: Map.get(attrs, "visible") || Map.get(attrs, :visible, true),
        template: Map.get(attrs, "template") || Map.get(attrs, :template, "default"),
        position: Map.get(attrs, "position") || Map.get(attrs, :position, 0)
      })

    page
  end

  def section_fixture(attrs \\ %{}) do
    attrs = to_map(attrs)
    page = Map.get_lazy(attrs, "page", fn -> Map.get_lazy(attrs, :page, fn -> page_fixture() end) end)

    {:ok, section} =
      Site.create_section(%{
        title: Map.get(attrs, "title") || Map.get(attrs, :title, "Test Section"),
        slug: Map.get(attrs, "slug") || Map.get(attrs, :slug, "test-section-#{System.unique_integer()}"),
        content: Map.get(attrs, "content") || Map.get(attrs, :content, "<p>Test section content</p>"),
        visible: Map.get(attrs, "visible") || Map.get(attrs, :visible, true),
        template: Map.get(attrs, "template") || Map.get(attrs, :template, "default"),
        position: Map.get(attrs, "position") || Map.get(attrs, :position, 0),
        page_id: page.id
      })

    section
  end
end
