defmodule MykonosBiennale.SiteFixtures do
  @moduledoc """
  This module defines test helpers for creating
  entities via the `MykonosBiennale.Site` context.
  """

  @doc """
  Generate a page.
  """
  def page_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        html: "some html",
        metadata: %{},
        slug: "some slug",
        template: "some template",
        title: "some title"
      })

    {:ok, page} = MykonosBiennale.Site.create_page(scope, attrs)
    page
  end

  @doc """
  Generate a section.
  """
  def section_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        content: "some content",
        metadata: %{},
        slug: "some slug",
        title: "some title",
        visible: true
      })

    {:ok, section} = MykonosBiennale.Site.create_section(scope, attrs)
    section
  end

  @doc """
  Generate a page.
  """
  def page_fixture(scope, attrs \\ %{}) do
    attrs =
      Enum.into(attrs, %{
        content: "some content",
        description: "some description",
        metadata: %{},
        slug: "some slug",
        template: :node,
        title: "some title",
        visible: true
      })

    {:ok, page} = MykonosBiennale.Site.create_page(scope, attrs)
    page
  end

  @doc """
  Generate a page.
  """
  def page_fixture(attrs \\ %{}) do
    {:ok, page} =
      attrs
      |> Enum.into(%{
        content: "some content",
        description: "some description",
        metadata: %{},
        slug: "some slug",
        template: :node,
        title: "some title",
        visible: true
      })
      |> MykonosBiennale.Site.create_page()

    page
  end

  @doc """
  Generate a section.
  """
  def section_fixture(attrs \\ %{}) do
    {:ok, section} =
      attrs
      |> Enum.into(%{
        content: "some content",
        description: "some description",
        metadata: %{},
        slug: "some slug",
        template: :node,
        title: "some title",
        visible: true
      })
      |> MykonosBiennale.Site.create_section()

    section
  end
end
