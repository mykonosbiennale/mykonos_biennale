defmodule MykonosBiennaleWeb.Fields.CodeEditor do
  @config_schema [
    placeholder: [
      doc: "Placeholder value or function that receives the assigns.",
      type: {:or, [:string, {:fun, 1}]}
    ],
    mode: [
      doc: "Ace Editor mode (e.g., 'html', 'css', 'javascript', 'elixir', 'json', 'markdown'). Defaults to 'html'.",
      type: :string,
      default: "html"
    ],
    theme: [
      doc: "Ace Editor theme (e.g., 'monokai', 'github', 'tomorrow'). Defaults to 'monokai'.",
      type: :string,
      default: "monokai"
    ],
    min_lines: [
      doc: "Minimum number of lines to display.",
      type: :pos_integer,
      default: 10
    ],
    max_lines: [
      doc: "Maximum number of lines to display (Infinity for unlimited).",
      type: {:or, [:pos_integer, :string]},
      default: 30
    ],
    font_size: [
      doc: "Font size in pixels.",
      type: :pos_integer,
      default: 14
    ],
    show_gutter: [
      doc: "Show line numbers.",
      type: :boolean,
      default: true
    ],
    show_print_margin: [
      doc: "Show print margin.",
      type: :boolean,
      default: false
    ],
    readonly: [
      doc: "Sets the field to readonly. Also see the [panels](/guides/fields/readonly.md) guide.",
      type: {:or, [:boolean, {:fun, 1}]}
    ]
  ]

  @moduledoc """
  A field for editing code with syntax highlighting using Ace Editor.

  This field provides a rich code editing experience with features like:
  - Syntax highlighting for multiple languages
  - Line numbers
  - Code folding
  - Multiple themes
  - Auto-indentation

  ## Field-specific options

  See `Backpex.Field` for general field options.

  #{NimbleOptions.docs(@config_schema)}

  ## Example

      content: %{
        module: MykonosBiennaleWeb.Fields.CodeEditor,
        label: "HTML Content",
        mode: "html",
        theme: "monokai",
        min_lines: 15,
        max_lines: 50
      }
  """
  use Backpex.Field, config_schema: @config_schema

  @impl Backpex.Field
  def render_value(assigns) do
    ~H"""
    <div class={@live_action in [:index, :resource_action] && "truncate"}>
      <code class="text-sm"><%= HTML.pretty_value(@value) %></code>
    </div>
    """
  end

  @impl Backpex.Field
  def render_form(assigns) do
    editor_id = "code-editor-#{assigns.name}-#{System.unique_integer([:positive])}"

    assigns =
      assigns
      |> assign(:editor_id, editor_id)
      |> assign(:editor_config, %{
        mode: assigns.field_options[:mode],
        theme: assigns.field_options[:theme],
        minLines: assigns.field_options[:min_lines],
        maxLines: assigns.field_options[:max_lines],
        fontSize: assigns.field_options[:font_size],
        showGutter: assigns.field_options[:show_gutter],
        showPrintMargin: assigns.field_options[:show_print_margin],
        readOnly: assigns.readonly
      })

    ~H"""
    <div>
      <Layout.field_container>
        <:label align={Backpex.Field.align_label(@field_options, assigns, :top)}>
          <Layout.input_label text={@field_options[:label]} />
        </:label>
        <div class="relative">
          <%!-- Hidden textarea that syncs with Ace Editor --%>
          <textarea
            id={"#{@editor_id}-input"}
            name={Phoenix.HTML.Form.input_name(@form, @name)}
            class="hidden"
          ><%= Phoenix.HTML.Form.input_value(@form, @name) %></textarea>
          <%!-- Ace Editor container --%>
          <div
            id={@editor_id}
            phx-hook="CodeEditor"
            data-config={Jason.encode!(@editor_config)}
            data-target-id={"#{@editor_id}-input"}
            class="border border-base-300 rounded-lg overflow-hidden"
            style="min-height: 200px;"
          >
            <%= Phoenix.HTML.Form.input_value(@form, @name) %>
          </div>
          <%= if help_text = Backpex.Field.help_text(@field_options, assigns) do %>
            <p class="mt-2 text-sm text-base-content/70"><%= help_text %></p>
          <% end %>
          <%!-- Error display --%>
          <.error :for={msg <- Enum.map(Keyword.get_values(@form.errors || [], @name), &Backpex.Field.translate_error_fun(@field_options, assigns).(&1))}>
            <%= msg %>
          </.error>
        </div>
      </Layout.field_container>
    </div>
    """
  end

  @impl Backpex.Field
  def render_index_form(assigns) do
    form = to_form(%{"value" => assigns.value}, as: :index_form)
    editor_id = "code-editor-index-#{assigns.name}-#{LiveResource.primary_value(assigns.item, assigns.live_resource)}"

    assigns =
      assigns
      |> assign_new(:form, fn -> form end)
      |> assign_new(:valid, fn -> true end)
      |> assign(:editor_id, editor_id)
      |> assign(:editor_config, %{
        mode: assigns.field_options[:mode],
        theme: assigns.field_options[:theme],
        minLines: 5,
        maxLines: 10,
        fontSize: 12,
        showGutter: false,
        showPrintMargin: false,
        readOnly: assigns.readonly
      })

    ~H"""
    <div>
      <.form for={@form} class="relative" phx-change="update-field" phx-submit="update-field" phx-target={@myself}>
        <%!-- Hidden input for index inline editing --%>
        <input
          type="hidden"
          id={"#{@editor_id}-input"}
          name="index_form[value]"
          value={@form[:value].value}
        />
        <%!-- Compact Ace Editor for index --%>
        <div
          id={@editor_id}
          phx-hook="CodeEditor"
          data-config={Jason.encode!(@editor_config)}
          data-target-id={"#{@editor_id}-input"}
          class={["border rounded", @valid && "border-base-300", !@valid && "border-error"]}
          style="min-height: 100px; font-size: 12px;"
        >
          <%= @form[:value].value %>
        </div>
      </.form>
    </div>
    """
  end

  @impl Phoenix.LiveComponent
  def handle_event("update-field", %{"index_form" => %{"value" => value}}, socket) do
    Backpex.Field.handle_index_editable(socket, value, Map.put(%{}, socket.assigns.name, value))
  end

  # Error component helper
  attr :rest, :global
  slot :inner_block, required: true

  defp error(assigns) do
    ~H"""
    <p class="mt-2 flex gap-2 text-sm leading-6 text-error" {@rest}>
      <.icon name="hero-exclamation-circle" class="h-5 w-5 flex-none" />
      <%= render_slot(@inner_block) %>
    </p>
    """
  end

  # Icon component helper
  attr :name, :string, required: true
  attr :class, :string, default: nil

  defp icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end
end
