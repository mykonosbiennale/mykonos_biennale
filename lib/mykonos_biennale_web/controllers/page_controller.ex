defmodule MykonosBiennaleWeb.PageController do
  use MykonosBiennaleWeb, :controller
  alias MykonosBiennale.Content
  alias MykonosBiennaleWeb.BiennaleController

  def home(conn, _params) do
    current_biennale_year =
      Application.get_env(:mykonos_biennale, :current_biennale_year, 2021)

    current_biennale = Content.get_biennale_by_year(current_biennale_year)

    raw_projects =
      if current_biennale do
        Content.list_projects_for_biennale(current_biennale.fields["year"])
      else
        []
      end

    project_media =
      raw_projects
      |> Enum.map(fn p ->
        media = Content.list_media_for_entity(p)
        {p.id, if(media == [], do: Content.list_event_media_for_project(p), else: media)}
      end)
      |> Enum.into(%{})

    projects = Enum.map(raw_projects, &present_project/1)

    raw_events =
      if current_biennale do
        Content.list_events_for_biennale(current_biennale.fields["year"])
      else
        []
      end

    events = Enum.map(raw_events, &present_event/1)

    project_event_map =
      events
      |> Enum.filter(& &1[:project_id])
      |> Enum.into(%{}, fn event -> {event.project_id, event.id} end)

    biennales = Content.list_biennales()

    biennale_media =
      if current_biennale do
        Content.list_media_for_entity(current_biennale)
      else
        []
      end

    biennale_media_map =
      biennales
      |> Enum.map(fn b -> {b.id, Content.list_media_for_entity(b)} end)
      |> Enum.into(%{})

    conn
    |> assign(:page_title, page_title(current_biennale))
    |> assign(:biennale, current_biennale)
    |> assign(:projects, projects)
    |> assign(:events, events)
    |> assign(:biennales, biennales)
    |> assign(:biennale_media, biennale_media)
    |> assign(:biennale_media_map, biennale_media_map)
    |> assign(:project_media, project_media)
    |> assign(:project_event_map, project_event_map)
    |> put_view(MykonosBiennaleWeb.BiennaleHTML)
    |> BiennaleController.render_template(current_biennale)
  end

  defp present_project(%MykonosBiennale.Content.Entity{} = entity) do
    media = Content.list_media_for_entity(entity)
    media = if media == [], do: Content.list_event_media_for_project(entity), else: media

    background =
      case List.last(media) do
        %{source_type: "upload"} = m ->
          MykonosBiennale.Uploads.media_url(m, size: "card")

        %{source_type: "url", source_url: url} when is_binary(url) ->
          url

        _ ->
          nil
      end

    %{
      id: entity.id,
      title: entity.fields["title"],
      description: entity.fields["description"],
      statement: entity.fields["statement"],
      slug: entity.slug,
      background_image: background
    }
  end

  defp present_event(%MykonosBiennale.Content.Entity{} = entity) do
    media = Content.list_media_for_entity(entity)

    background =
      case List.last(media) do
        %{source_type: "upload"} = m ->
          MykonosBiennale.Uploads.media_url(m, size: "card")

        %{source_type: "url", source_url: url} when is_binary(url) ->
          url

        _ ->
          nil
      end

    project_id = get_event_project_id(entity)

    %{
      id: entity.id,
      title: entity.fields["title"],
      type: entity.fields["type"],
      date: entity.fields["date"],
      time: entity.fields["time"],
      location: entity.fields["location"],
      description: entity.fields["description"],
      slug: entity.slug,
      background_image: background,
      project_id: project_id
    }
  end

  defp get_event_project_id(event) do
    import Ecto.Query
    alias MykonosBiennale.Repo
    alias MykonosBiennale.Content.{Relationship, RelationshipType}

    rt = Repo.get_by(RelationshipType, slug: "event_project")

    if rt do
      Repo.one(
        from r in Relationship,
          where: r.subject_id == ^event.id and r.relationship_type_id == ^rt.id,
          select: r.object_id
      )
    else
      nil
    end
  end

  defp page_title(nil), do: "Mykonos Biennale"
  defp page_title(biennale), do: "Mykonos Biennale #{biennale.fields["year"]}"
end
