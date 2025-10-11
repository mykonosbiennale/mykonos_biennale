defmodule MykonosBiennaleWeb.Admin.ParticipantLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: MykonosBiennale.Data.Participant,
      repo: MykonosBiennale.Repo,
      update_changeset: &MykonosBiennale.Data.Participant.changeset/3,
      create_changeset: &MykonosBiennale.Data.Participant.changeset/3,
      item_query: &__MODULE__.item_query/3
    ],
    layout: {MykonosBiennaleWeb.Layouts, :admin},
    fluid?: true,
    save_and_continue_button?: true,
    init_order: %{by: :position, direction: :asc}

  import Ecto.Query, warn: false

  def item_query(query, :index, _assigns) do
    query
    |> where([_entity], fragment("fields->>'type' = 'participant'"))
  end

  def item_query(query, _live_action, _assigns), do: query

  @impl Backpex.LiveResource
  def singular_name, do: "Entity"

  @impl Backpex.LiveResource
  def plural_name, do: "Entities"

  @impl Backpex.LiveResource
  def can?(_assigns, _action, _item), do: true

  @impl Backpex.LiveResource
  def fields do
    [
      identity: %{
        module: Backpex.Fields.Text,
        label: "Identity",
        searchable: true,
        index_editable: true
      },
      visible: %{
        module: Backpex.Fields.Boolean,
        label: "Visible",
        index_editable: true
      },
      slug: %{
        module: Backpex.Fields.Text,
        label: "Slug",
        searchable: true
      },
      fields: %{
        module: BackpexTV.Fields.InlineCRUD,
        label: "Fields",
        type: :embed_one,
        except: [:index],
        child_fields: [
          phone: %{
            module: Backpex.Fields.Text,
            label: "Phone"
          },
          email: %{
            module: Backpex.Fields.Text,
            label: "Email"
          }
        ]
      },
      as_subject: %{
        module: Backpex.Fields.HasMany,
        label: "As Subject",
        display_field: :name,
        live_resource: MykonosBiennaleWeb.Admin.RelationshipLive
      },
      as_object: %{
        module: Backpex.Fields.HasMany,
        label: "As Object",
        display_field: :name,
        live_resource: MykonosBiennaleWeb.Admin.RelationshipLive
      }
    ]
  end
end
