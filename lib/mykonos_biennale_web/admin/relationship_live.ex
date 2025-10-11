defmodule MykonosBiennaleWeb.Admin.RelationshipLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: MykonosBiennale.Data.Relationship,
      repo: MykonosBiennale.Repo,
      update_changeset: &MykonosBiennale.Data.Relationship.changeset/3,
      create_changeset: &MykonosBiennale.Data.Relationship.changeset/3
    ],
    layout: {MykonosBiennaleWeb.Layouts, :admin},
    fluid?: true,
    save_and_continue_button?: true,
    init_order: %{by: :position, direction: :asc}

  import Ecto.Query, warn: false

  @impl Backpex.LiveResource
  def singular_name, do: "Relationship"

  @impl Backpex.LiveResource
  def plural_name, do: "Relationships"

  @impl Backpex.LiveResource
  def can?(_assigns, _action, _item), do: true

  # def filters do
  #   [
  #     page_id: %{
  #       module: MykonosBiennaleWeb.Filters.PageSelect,
  #       label: "Page"
  #     }
  #   ]
  # end

  @impl Backpex.LiveResource
  def fields do
    [
      name: %{
        module: Backpex.Fields.Text,
        label: "Name",
        searchable: true,
        index_editable: true
      },
      slug: %{
        module: Backpex.Fields.Text,
        label: "Slug",
        searchable: true,
        index_editable: true
      },
      subject: %{
        module: Backpex.Fields.BelongsTo,
        label: "Subject",
        display_field: :identity,
        live_resource: MykonosBiennaleWeb.Admin.EntityLive,
        index_editable: true
      },
      object: %{
        module: Backpex.Fields.BelongsTo,
        label: "Object",
        display_field: :identity,
        live_resource: MykonosBiennaleWeb.Admin.EntityLive,
        index_editable: true
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
