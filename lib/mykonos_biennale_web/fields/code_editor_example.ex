defmodule MykonosBiennaleWeb.CodeEditorExample do
  @moduledoc """
  Example Backpex resource configuration using the CodeEditor field.

  This is a demonstration of how to use the custom CodeEditor field
  in your Backpex resources. You can copy these configurations into
  your actual resource modules.

  ## Usage

  In your Backpex resource (e.g., `MyAppWeb.Admin.PageLive`), add fields like:

      def fields do
        [
          # ... other fields ...
          html_content: %{
            module: MykonosBiennaleWeb.Fields.CodeEditor,
            label: "HTML Content",
            mode: "html",
            theme: "monokai",
            min_lines: 15,
            max_lines: 50
          },
          # ... more fields ...
        ]
      end
  """

  @doc """
  Example field configurations for different use cases.
  """
  def example_fields do
    [
      # HTML content editor
      html_content: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "HTML Content",
        mode: "html",
        theme: "monokai",
        min_lines: 15,
        max_lines: 50,
        font_size: 14,
        show_gutter: true,
        placeholder: "Enter your HTML code here..."
      },

      # CSS stylesheet editor
      css_styles: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "CSS Styles",
        mode: "css",
        theme: "github",
        min_lines: 10,
        max_lines: 40,
        font_size: 13,
        show_gutter: true
      },

      # JavaScript code editor
      javascript_code: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "JavaScript",
        mode: "javascript",
        theme: "tomorrow",
        min_lines: 10,
        max_lines: 30,
        show_gutter: true
      },

      # JSON configuration editor
      json_config: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "JSON Configuration",
        mode: "json",
        theme: "monokai",
        min_lines: 8,
        max_lines: 25,
        font_size: 13
      },

      # Markdown editor
      markdown_content: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "Markdown Content",
        mode: "markdown",
        theme: "github",
        min_lines: 15,
        max_lines: "Infinity",
        font_size: 14,
        show_gutter: false
      },

      # Elixir code editor
      elixir_code: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "Elixir Code",
        mode: "elixir",
        theme: "tomorrow_night",
        min_lines: 10,
        max_lines: 40,
        show_gutter: true
      },

      # SQL query editor
      sql_query: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "SQL Query",
        mode: "sql",
        theme: "chrome",
        min_lines: 8,
        max_lines: 20,
        font_size: 13
      },

      # Read-only code viewer
      readonly_code: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "Source Code (View Only)",
        mode: "javascript",
        theme: "github",
        min_lines: 10,
        max_lines: 30,
        readonly: true,
        only: [:show, :index]
      },

      # Conditional read-only based on action
      conditional_editor: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "Code",
        mode: "html",
        theme: "monokai",
        readonly: fn assigns -> assigns.live_action == :show end
      },

      # Compact editor for index inline editing
      inline_editable_code: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "Quick Edit",
        mode: "html",
        theme: "github",
        min_lines: 5,
        max_lines: 15,
        font_size: 12,
        index_editable: true
      }
    ]
  end

  @doc """
  Example of a complete Backpex resource using CodeEditor.

  This would typically be in a file like:
  `lib/my_app_web/admin/page_live.ex`
  """
  def example_resource do
    """
    defmodule MyAppWeb.Admin.PageLive do
      use Backpex.LiveResource,
        layout: {MyAppWeb.Layouts, :admin},
        schema: MyApp.Content.Page,
        repo: MyApp.Repo,
        update_changeset: &MyApp.Content.Page.changeset/2,
        create_changeset: &MyApp.Content.Page.changeset/2,
        pubsub: MyApp.PubSub,
        topic: "pages",
        event_prefix: "page_"

      @impl Backpex.LiveResource
      def singular_name, do: "Page"

      @impl Backpex.LiveResource
      def plural_name, do: "Pages"

      @impl Backpex.LiveResource
      def fields do
        [
          title: %{
            module: Backpex.Fields.Text,
            label: "Title"
          },
          slug: %{
            module: Backpex.Fields.Text,
            label: "Slug"
          },
          html_content: %{
            module: MykonosBiennaleWeb.Fields.CodeEditor,
            label: "HTML Content",
            mode: "html",
            theme: "monokai",
            min_lines: 20,
            max_lines: 60,
            font_size: 14,
            help_text: "Enter the HTML content for this page"
          },
          css_styles: %{
            module: MykonosBiennaleWeb.Fields.CodeEditor,
            label: "Custom CSS",
            mode: "css",
            theme: "github",
            min_lines: 10,
            max_lines: 40,
            only: [:edit, :new],
            help_text: "Optional custom CSS for this page"
          },
          javascript: %{
            module: MykonosBiennaleWeb.Fields.CodeEditor,
            label: "Custom JavaScript",
            mode: "javascript",
            theme: "tomorrow",
            min_lines: 10,
            max_lines: 40,
            only: [:edit, :new],
            help_text: "Optional custom JavaScript for this page"
          },
          published: %{
            module: Backpex.Fields.Boolean,
            label: "Published"
          },
          inserted_at: %{
            module: Backpex.Fields.DateTime,
            label: "Created At",
            only: [:show, :index]
          }
        ]
      end
    end
    """
  end

  @doc """
  Example schema that works with the CodeEditor field.
  """
  def example_schema do
    """
    defmodule MyApp.Content.Page do
      use Ecto.Schema
      import Ecto.Changeset

      schema "pages" do
        field :title, :string
        field :slug, :string
        field :html_content, :string
        field :css_styles, :string
        field :javascript, :string
        field :published, :boolean, default: false

        timestamps()
      end

      def changeset(page, attrs) do
        page
        |> cast(attrs, [:title, :slug, :html_content, :css_styles, :javascript, :published])
        |> validate_required([:title, :slug, :html_content])
        |> validate_length(:html_content, min: 10, max: 100_000)
        |> unique_constraint(:slug)
      end
    end
    """
  end
end
