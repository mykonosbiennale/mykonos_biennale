defmodule MykonosBiennaleWeb.Admin.SectionLive do
  use Backpex.LiveResource,
    adapter_config: [
      schema: MykonosBiennale.Site.Section,
      repo: MykonosBiennale.Repo,
      update_changeset: &MykonosBiennale.Site.Section.changeset/3,
      create_changeset: &MykonosBiennale.Site.Section.changeset/3
    ],
    layout: {MykonosBiennaleWeb.Layouts, :admin},
    fluid?: true,
    save_and_continue_button?: true

  import Ecto.Query, warn: false

  @impl Backpex.LiveResource
  def singular_name, do: "Section"

  @impl Backpex.LiveResource
  def plural_name, do: "Sections"

  @impl Backpex.LiveResource
  def can?(_assigns, _action, _item), do: true

  def filters do
    [
      page_id: %{
        module: MykonosBiennaleWeb.Filters.PageSelect,
        label: "Page"
      }
    ]
  end

  @impl Backpex.LiveResource
  def fields do
    [
      title: %{
        module: Backpex.Fields.Text,
        label: "Title",
        searchable: true
      },
      page: %{
        module: Backpex.Fields.BelongsTo,
        label: "Page",
        display_field: :title,
        live_resource: MykonosBiennaleWeb.Admin.PageLive
      },
      visible: %{
        module: Backpex.Fields.Boolean,
        label: "Visible"
      },
      slug: %{
        module: Backpex.Fields.Text,
        label: "Slug  ",
        searchable: true
      },
      description: %{
        module: Backpex.Fields.Textarea,
        rows: 3,
        label: "Description",
        searchable: true,
        only: [:edit, :new, :show]
      },
      template: %{
        module: Backpex.Fields.Select,
        label: "Template",
        options: [
          {"None", ""},
          {"Default", "default"}
        ]
      },
      content: %{
        module: Backpex.Fields.Textarea,
        label: "Content",
        rows: 10,
        except: [:index],
        align_label: :center
      },
      inserted_at: %{
        module: Backpex.Fields.DateTime,
        label: "Created At",
        only: [:index, :show]
      }
    ]
  end
end
