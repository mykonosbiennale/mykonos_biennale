defmodule MykonosBiennale.Site do
  @moduledoc """
  The Site context for managing Pages and Sections.
  """

  import Ecto.Query, warn: false
  alias MykonosBiennale.Repo
  alias MykonosBiennale.Site.{Page, Section}

  ## Pages

  @doc """
  Returns the list of pages.

  ## Examples

      iex> list_pages()
      [%Page{}, ...]

  """
  def list_pages do
    Repo.all(from p in Page, order_by: p.position, preload: [:sections])
  end

  @doc """
  Returns the list of visible pages.
  """
  def list_visible_pages do
    Repo.all(from p in Page, where: p.visible == true, order_by: p.position, preload: [:sections])
  end

  @doc """
  Gets a single page.

  Raises `Ecto.NoResultsError` if the Page does not exist.

  ## Examples

      iex> get_page!(123)
      %Page{}

      iex> get_page!(456)
      ** (Ecto.NoResultsError)

  """
  def get_page!(id) do
    Repo.get!(Page, id) |> Repo.preload(:sections)
  end

  @doc """
  Gets a page by slug.
  """
  def get_page_by_slug(slug) do
    Repo.get_by(Page, slug: slug) |> Repo.preload(:sections)
  end

  @doc """
  Creates a page.

  ## Examples

      iex> create_page(%{field: value})
      {:ok, %Page{}}

      iex> create_page(%{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def create_page(attrs \\ %{}) do
    %Page{}
    |> Page.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a page.

  ## Examples

      iex> update_page(page, %{field: new_value})
      {:ok, %Page{}}

      iex> update_page(page, %{field: bad_value})
      {:error, %Ecto.Changeset{}}

  """
  def update_page(%Page{} = page, attrs) do
    page
    |> Page.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a page.

  ## Examples

      iex> delete_page(page)
      {:ok, %Page{}}

      iex> delete_page(page)
      {:error, %Ecto.Changeset{}}

  """
  def delete_page(%Page{} = page) do
    Repo.delete(page)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking page changes.

  ## Examples

      iex> change_page(page)
      %Ecto.Changeset{data: %Page{}}

  """
  def change_page(%Page{} = page, attrs \\ %{}) do
    Page.changeset(page, attrs)
  end

  ## Sections

  @doc """
  Returns the list of all sections.
  """
  def list_sections do
    Repo.all(from s in Section, order_by: s.position, preload: [:page])
  end

  @doc """
  Returns the list of sections for a page.
  """
  def list_sections_for_page(page_id) do
    Repo.all(from s in Section, where: s.page_id == ^page_id, order_by: s.position)
  end

  @doc """
  Returns the list of visible sections for a page.
  """
  def list_visible_sections_for_page(page_id) do
    Repo.all(
      from s in Section, where: s.page_id == ^page_id and s.visible == true, order_by: s.position
    )
  end

  @doc """
  Gets a single section.

  Raises `Ecto.NoResultsError` if the Section does not exist.
  """
  def get_section!(id) do
    Repo.get!(Section, id) |> Repo.preload(:page)
  end

  @doc """
  Creates a section.
  """
  def create_section(attrs \\ %{}) do
    %Section{}
    |> Section.changeset(attrs)
    |> Repo.insert()
  end

  @doc """
  Updates a section.
  """
  def update_section(%Section{} = section, attrs) do
    section
    |> Section.changeset(attrs)
    |> Repo.update()
  end

  @doc """
  Deletes a section.
  """
  def delete_section(%Section{} = section) do
    Repo.delete(section)
  end

  @doc """
  Returns an `%Ecto.Changeset{}` for tracking section changes.
  """
  def change_section(%Section{} = section, attrs \\ %{}) do
    Section.changeset(section, attrs)
  end
end
