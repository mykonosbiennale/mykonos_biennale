defmodule MykonosBiennale.ContentFixtures do
  @moduledoc """
  Test fixtures for the Content context.
  Creates Entity, Media, Relationship, and RelationshipType records for testing.
  """

  alias MykonosBiennale.{Repo, Content}
  alias MykonosBiennale.Content.RelationshipType

  @doc "Ensures all standard relationship types exist. Call in setup."
  def ensure_relationship_types do
    types = [
      {"biennale_event", "belongs_to_biennale"},
      {"event_project", "is_a"},
      {"artwork_participant", "created_by"},
      {"artwork_event", "exhibited_at"},
      {"screened_at", "screened_at"},
      {"directed", "directed"},
      {"event_festival", "part_of"}
    ]

    Enum.each(types, fn {slug, label} ->
      Repo.get_by(RelationshipType, slug: slug) ||
        %RelationshipType{}
        |> RelationshipType.changeset(%{slug: slug, label: label})
        |> Repo.insert!()
    end)

    :ok
  end

  # Converts keyword list or map to a map.
  defp to_map(attrs) when is_list(attrs), do: Enum.into(attrs, %{})
  defp to_map(attrs) when is_map(attrs), do: attrs
  defp to_map(_), do: %{}

  @doc "Creates a biennale entity."
  def biennale_fixture(attrs \\ %{}) do
    attrs = to_map(attrs)
    year = Map.get(attrs, "year") || Map.get(attrs, :year, 2025)
    theme = Map.get(attrs, "theme") || Map.get(attrs, :theme, "Test Theme")

    {:ok, biennale} =
      Content.create_biennale(%{
        year: year,
        theme: theme,
        statement: Map.get(attrs, "statement") || Map.get(attrs, :statement),
        description: Map.get(attrs, "description") || Map.get(attrs, :description),
        visible: Map.get(attrs, "visible") || Map.get(attrs, :visible, true),
        template: Map.get(attrs, "template") || Map.get(attrs, :template, "default"),
        start_date: Map.get(attrs, "start_date") || Map.get(attrs, :start_date, "2025-09-27"),
        end_date: Map.get(attrs, "end_date") || Map.get(attrs, :end_date, "2025-10-05"),
        show_program: Map.get(attrs, "show_program") || Map.get(attrs, :show_program, true)
      })

    biennale
  end

  @doc "Creates a project entity."
  def project_fixture(attrs \\ %{}) do
    attrs = to_map(attrs)
    title = Map.get(attrs, "title") || Map.get(attrs, :title, "Test Project")

    {:ok, project} =
      Content.create_entity(%{
        identity: title,
        type: "project",
        slug: Content.slugify(title) <> "-#{System.unique_integer()}",
        visible: Map.get(attrs, "visible") || Map.get(attrs, :visible, true),
        fields: %{
          "title" => title,
          "description" => Map.get(attrs, "description") || Map.get(attrs, :description)
        }
      })

    project
  end

  @doc "Creates an event entity with relationships to biennale and project."
  def event_fixture(attrs \\ %{}) do
    attrs = to_map(attrs)
    ensure_relationship_types()

    biennale =
      Map.get_lazy(attrs, "biennale", fn ->
        Map.get_lazy(attrs, :biennale, fn -> biennale_fixture() end)
      end)

    project =
      Map.get_lazy(attrs, "project", fn ->
        Map.get_lazy(attrs, :project, fn -> project_fixture() end)
      end)

    {:ok, event} =
      Content.create_event(%{
        title: Map.get(attrs, "title") || Map.get(attrs, :title, "Test Event"),
        type: Map.get(attrs, "type") || Map.get(attrs, :type, "exhibition"),
        biennale_id: biennale.id,
        project_id: project.id,
        date: Map.get(attrs, "date") || Map.get(attrs, :date, "2025-09-28"),
        time: Map.get(attrs, "time") || Map.get(attrs, :time, "18:00"),
        location: Map.get(attrs, "location") || Map.get(attrs, :location, "Test Venue"),
        description:
          Map.get(attrs, "description") || Map.get(attrs, :description, "A test event"),
        show_project: Map.get(attrs, "show_project") || Map.get(attrs, :show_project, true),
        visible: Map.get(attrs, "visible") || Map.get(attrs, :visible, true)
      })

    event
  end

  @doc "Creates a simple event entity without relationships."
  def simple_event_fixture(attrs \\ %{}) do
    attrs = to_map(attrs)
    title = Map.get(attrs, "title") || Map.get(attrs, :title, "Simple Event")

    {:ok, event} =
      Content.create_entity(%{
        identity: title,
        type: "event",
        slug: Content.slugify(title) <> "-#{System.unique_integer()}",
        visible: Map.get(attrs, "visible") || Map.get(attrs, :visible, true),
        fields: %{
          "title" => title,
          "type" => Map.get(attrs, "type") || Map.get(attrs, :type, "exhibition"),
          "date" => Map.get(attrs, "date") || Map.get(attrs, :date),
          "time" => Map.get(attrs, "time") || Map.get(attrs, :time),
          "location" => Map.get(attrs, "location") || Map.get(attrs, :location),
          "description" => Map.get(attrs, "description") || Map.get(attrs, :description),
          "show_project" => Map.get(attrs, "show_project") || Map.get(attrs, :show_project, true)
        }
      })

    event
  end

  @doc "Creates an artwork entity."
  def artwork_fixture(attrs \\ %{}) do
    attrs = to_map(attrs)
    title = Map.get(attrs, "title") || Map.get(attrs, :title, "Test Artwork")

    {:ok, artwork} =
      Content.Artwork.create(%{
        title: title,
        date: Map.get(attrs, "date") || Map.get(attrs, :date, "2025"),
        medium: Map.get(attrs, "medium") || Map.get(attrs, :medium, "Oil on canvas"),
        size: Map.get(attrs, "size") || Map.get(attrs, :size, "100 x 80 cm"),
        description:
          Map.get(attrs, "description") || Map.get(attrs, :description, "A test artwork"),
        type: Map.get(attrs, "artwork_type") || Map.get(attrs, :artwork_type, "artwork"),
        visible: Map.get(attrs, "visible") || Map.get(attrs, :visible, true)
      })

    artwork
  end

  @doc "Creates a film entity."
  def film_fixture(attrs \\ %{}) do
    attrs = to_map(attrs)
    title = Map.get(attrs, "title") || Map.get(attrs, :title, "Test Film")

    base = %{
      title: title,
      type: Map.get(attrs, "type") || Map.get(attrs, :type, "Short Film"),
      dir_by: Map.get(attrs, "dir_by") || Map.get(attrs, :dir_by, "Test Director"),
      country: Map.get(attrs, "country") || Map.get(attrs, :country, "Greece"),
      runtime: Map.get(attrs, "runtime") || Map.get(attrs, :runtime, 10),
      log_line:
        Map.get(attrs, "log_line") || Map.get(attrs, :log_line, "A test film about testing."),
      visible: Map.get(attrs, "visible", Map.get(attrs, :visible, true))
    }

    extra =
      attrs
      |> Map.drop([
        "title",
        "type",
        "dir_by",
        "country",
        "runtime",
        "log_line",
        "visible",
        :title,
        :type,
        :dir_by,
        :country,
        :runtime,
        :log_line,
        :visible
      ])
      |> Enum.reject(fn {_k, v} -> is_nil(v) end)
      |> Enum.into(%{})

    {:ok, film} = Content.Film.create(Map.merge(base, extra))

    film
  end

  @doc "Creates a participant entity."
  def participant_fixture(attrs \\ %{}) do
    attrs = to_map(attrs)

    {:ok, participant} =
      Content.create_participant(%{
        first_name: Map.get(attrs, "first_name") || Map.get(attrs, :first_name, "Jane"),
        last_name: Map.get(attrs, "last_name") || Map.get(attrs, :last_name, "Doe"),
        country: Map.get(attrs, "country") || Map.get(attrs, :country, "Greece"),
        bio: Map.get(attrs, "bio") || Map.get(attrs, :bio, "A test artist."),
        visible: Map.get(attrs, "visible") || Map.get(attrs, :visible, true)
      })

    participant
  end

  @doc "Creates a media record (upload type with slug)."
  def media_fixture(attrs \\ %{}) do
    attrs = to_map(attrs)

    {:ok, media} =
      Content.create_media(%{
        source_type: Map.get(attrs, "source_type") || Map.get(attrs, :source_type, "upload"),
        source_path:
          Map.get(attrs, "source_path") ||
            Map.get(attrs, :source_path, "test-#{System.unique_integer()}.jpg"),
        caption: Map.get(attrs, "caption") || Map.get(attrs, :caption, "Test Media"),
        original_name:
          Map.get(attrs, "original_name") || Map.get(attrs, :original_name, "test-image.jpg"),
        alt_text: Map.get(attrs, "alt_text") || Map.get(attrs, :alt_text)
      })

    media
  end

  @doc "Attaches media to an entity."
  def attach_media(entity, media, opts \\ []) do
    Content.attach_media_to_entity(entity, media, opts)
  end

  @doc "Creates a relationship between two entities by type slug."
  def create_relationship(subject, object, slug, fields \\ %{}) do
    ensure_relationship_types()

    Content.create_relationship(%{
      slug: slug,
      subject_id: subject.id,
      object_id: object.id,
      fields: fields
    })
  end

  @doc "Links an artwork to an event (artwork_event)."
  def link_artwork_to_event(artwork, event) do
    create_relationship(artwork, event, "artwork_event")
  end

  @doc "Links an artwork to a participant (artwork_participant)."
  def link_artwork_to_participant(artwork, participant) do
    create_relationship(artwork, participant, "artwork_participant")
  end

  @doc "Links a film to an event (screened_at)."
  def link_film_to_event(film, event) do
    create_relationship(film, event, "screened_at")
  end

  @doc "Links an event to a biennale (biennale_event)."
  def link_event_to_biennale(event, biennale) do
    create_relationship(event, biennale, "biennale_event")
  end

  @doc "Links an event to a project (event_project)."
  def link_event_to_project(event, project) do
    create_relationship(event, project, "event_project")
  end
end
