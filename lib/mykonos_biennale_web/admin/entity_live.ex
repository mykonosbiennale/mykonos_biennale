defmodule MykonosBiennaleWeb.Admin.EntityLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: MykonosBiennale.Data.Entity,
      repo: MykonosBiennale.Repo,
      update_changeset: &MykonosBiennale.Data.Entity.changeset/3,
      create_changeset: &MykonosBiennale.Data.Entity.changeset/3
    ],
    layout: {MykonosBiennaleWeb.Layouts, :admin},
    fluid?: true,
    save_and_continue_button?: true,
    init_order: %{by: :position, direction: :asc}

  import Ecto.Query, warn: false

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
      },
      fields: %{
        module: Backpex.Fields.Textarea,
        label: "Fields",
        rows: 10,
        except: [:index],
        align_label: :center
      }
    ]
  end
end
