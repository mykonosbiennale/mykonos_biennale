defmodule MykonosBiennaleWeb.BiennaleController do
  use MykonosBiennaleWeb, :controller

  alias MykonosBiennale.Content
  alias MykonosBiennaleWeb.BiennaleHTML

  def show(conn, %{"slug" => slug}) do
    case Content.get_entity_by_slug(slug) do
      %{type: "biennale", visible: true} = biennale ->
        projects = load_projects(biennale)
        events = load_events(biennale)
        biennales = Content.list_biennales()

        conn
        |> assign(:biennale, biennale)
        |> assign(:projects, projects)
        |> assign(:events, events)
        |> assign(:project_event_map, build_project_event_map(events))
        |> assign(:biennale_media, Content.list_media_for_entity(biennale))
        |> assign(:biennales, biennales)
        |> assign(:biennale_media_map, biennale_media_map(biennales))
        |> assign(:project_media, project_media_map(projects))
        |> assign(
          :page_title,
          "#{biennale.fields["theme"]} — Mykonos Biennale #{biennale.fields["year"]}"
        )
        |> render_template(biennale)

      %{visible: false} ->
        not_found(conn)

      nil ->
        not_found(conn)

      _ ->
        not_found(conn)
    end
  end

  defp load_events(biennale) do
    year = parse_year(biennale.fields["year"])
    Content.list_events_for_biennale(year) |> Enum.map(&present_event/1)
  end

  defp load_projects(biennale) do
    year = parse_year(biennale.fields["year"])
    Content.list_projects_for_biennale(year) |> Enum.map(&present_project/1)
  end

  defp biennale_media_map(biennales) do
    biennales
    |> Enum.map(fn b -> {b.id, Content.list_media_for_entity(b)} end)
    |> Enum.into(%{})
  end

  defp project_media_map(projects) do
    projects
    |> Enum.map(fn project ->
      entity = Content.get_entity!(project.id)
      media = Content.list_media_for_entity(entity)

      {project.id, if(media == [], do: Content.list_event_media_for_project(entity), else: media)}
    end)
    |> Enum.into(%{})
  end

  defp build_project_event_map(events) do
    events
    |> Enum.filter(& &1.project_id)
    |> Enum.into(%{}, fn event -> {event.project_id, event.id} end)
  end

  def render_template(conn, %{template: "none"}) do
    biennale = conn.assigns.biennale
    content = BiennaleHTML.render_content(biennale.fields["content"], conn.assigns)

    conn
    |> assign(:page_content, content)
    |> render(:none)
  end

  @biennale_templates ~w(biennale festival festival-2023 festival-2025 list none)a

  def render_template(conn, %{template: "default"}) do
    render(conn, :biennale)
  end

  def render_template(conn, %{template: template}) when is_binary(template) do
    template_atom = String.to_existing_atom(template)

    if template_atom in @biennale_templates do
      render(conn, template_atom)
    else
      render(conn, :biennale)
    end
  end

  def render_template(conn, _template) do
    render(conn, :biennale)
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

  defp parse_year(nil), do: nil
  defp parse_year(y) when is_integer(y), do: y

  defp parse_year(y) when is_binary(y) do
    case Integer.parse(y) do
      {n, _} -> n
      :error -> nil
    end
  end

  defp not_found(conn) do
    conn
    |> put_status(:not_found)
    |> put_view(MykonosBiennaleWeb.ErrorHTML)
    |> render(:"404")
  end
end
