defmodule MykonosBiennaleWeb.Admin.PageLive2 do
  use Backpex.LiveResource,
    layout: {MykonosBiennaleWeb.Layouts, :admin},
    adapter_config: [
      schema: MykonosBiennale.Site.Page,
      repo: MykonosBiennale.Repo,
      update_changeset: &__MODULE__.changeset/3,
      create_changeset: &__MODULE__.changeset/3,
      item_query: &__MODULE__.item_query/3
    ],
    pubsub: [
      server: MykonosBiennale.PubSub,
      topic: "pages"
    ]

  import Ecto.Query
  import MykonosBiennaleWeb.CoreComponents, only: [icon: 1]

  # Scope query to current user
  def item_query(query, _live_action, %{current_scope: scope}) do
    where(query, [p], p.user_id == ^scope.user.id)
  end

  # Wrapper changeset function that works with Backpex
  # The third parameter is metadata containing assigns and target
  def changeset(page, attrs, metadata) do
    assigns = Keyword.get(metadata, :assigns, %{})

    # Convert metadata JSON string to map
    attrs =
      case Map.get(attrs, "metadata") do
        nil ->
          attrs

        "" ->
          Map.put(attrs, "metadata", %{})

        json_string when is_binary(json_string) ->
          case Jason.decode(json_string) do
            {:ok, decoded} -> Map.put(attrs, "metadata", decoded)
            {:error, _} -> attrs
          end

        map when is_map(map) ->
          attrs
      end

    # Add user_id when creating new pages (only for new records)
    attrs =
      if is_nil(page.id) do
        # Access struct fields directly (Scope doesn't implement Access behavior)
        user_id =
          case assigns[:current_scope] do
            %{user: %{id: id}} -> id
            _ -> nil
          end

        if user_id, do: Map.put(attrs, "user_id", user_id), else: attrs
      else
        attrs
      end

    page
    |> Ecto.Changeset.cast(attrs, [:title, :slug, :html, :template, :metadata, :user_id])
    |> Ecto.Changeset.validate_required([:title, :slug, :html, :template])
  end

  @impl Backpex.LiveResource
  def singular_name, do: "Page"

  @impl Backpex.LiveResource
  def plural_name, do: "Pages"

  @impl Backpex.LiveResource
  def fields do
    [
      id: %{
        module: Backpex.Fields.Number,
        label: "ID",
        only: [:index, :show]
      },
      title: %{
        module: Backpex.Fields.Text,
        label: "Title",
        searchable: true,
        orderable: true
      },
      slug: %{
        module: Backpex.Fields.Text,
        label: "Slug",
        searchable: true,
        orderable: true,
        help_text: "URL-friendly identifier for this page"
      },
      template: %{
        module: Backpex.Fields.Text,
        label: "Template",
        placeholder: "default"
      },
      html: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "HTML Content",
        mode: "html",
        theme: "monokai",
        min_lines: 20,
        max_lines: 60,
        font_size: 14,
        show_gutter: true,
        show_print_margin: false,
        help_text: "The HTML content for this page. Full syntax highlighting available.",
        only: [:edit, :new, :show]
      },
      metadata: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "Metadata (JSON)",
        mode: "json",
        theme: "monokai",
        min_lines: 10,
        max_lines: 30,
        font_size: 13,
        show_gutter: true,
        help_text: "Page metadata in JSON format (e.g., SEO tags, custom properties)",
        render: fn assigns ->
          # Custom render to handle map to JSON conversion
          ~H"""
          <div class="overflow-x-auto">
            <pre class="text-sm bg-base-200 p-3 rounded"><code><%= if @value, do: Jason.encode!(@value, pretty: true), else: "{}" %></code></pre>
          </div>
          """
        end,
        only: [:edit, :new, :show]
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created At",
        only: [:show, :index],
        orderable: true
      },
      updated_at: %{
        module: Backpex.Fields.DateTime,
        label: "Updated At",
        only: [:show],
        orderable: true
      }
    ]
  end

  @impl Backpex.LiveResource
  def resource_actions, do: []

  @impl Backpex.LiveResource
  def can?(_assigns, _action, _item \\ nil), do: true

  @impl Backpex.LiveResource
  def render_resource_slot(assigns, :index, :after_header) do
    ~H"""
    <div class="alert alert-info mb-4">
      <.icon name="hero-information-circle" class="size-5" />
      <span>Manage your site pages with rich HTML editing capabilities.</span>
    </div>
    """
  end

  @impl Backpex.LiveResource
  def render_resource_slot(_assigns, _view, _slot), do: []
end
