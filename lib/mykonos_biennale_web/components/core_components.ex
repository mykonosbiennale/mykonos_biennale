defmodule MykonosBiennaleWeb.CoreComponents do
  @moduledoc """
  Provides core UI components.

  At first glance, this module may seem daunting, but its goal is to provide
  core building blocks for your application, such as tables, forms, and
  inputs. The components consist mostly of markup and are well-documented
  with doc strings and declarative assigns. You may customize and style
  them in any way you want, based on your application growth and needs.

  The foundation for styling is Tailwind CSS, a utility-first CSS framework,
  augmented with daisyUI, a Tailwind CSS plugin that provides UI components
  and themes. Here are useful references:

    * [daisyUI](https://daisyui.com/docs/intro/) - a good place to get
      started and see the available components.

    * [Tailwind CSS](https://tailwindcss.com) - the foundational framework
      we build on. You will use it for layout, sizing, flexbox, grid, and
      spacing.

    * [Heroicons](https://heroicons.com) - see `icon/1` for usage.

    * [Phoenix.Component](https://hexdocs.pm/phoenix_live_view/Phoenix.Component.html) -
      the component system used by Phoenix. Some components, such as `<.link>`
      and `<.form>`, are defined there.

  """
  use Phoenix.Component

  alias Phoenix.LiveView.JS

  @doc """
  Renders flash notices.

  ## Examples

      <.flash kind={:info} flash={@flash} />
      <.flash kind={:info} phx-mounted={show("#flash")}>Welcome Back!</.flash>
  """
  attr :id, :string, doc: "the optional id of flash container"
  attr :flash, :map, default: %{}, doc: "the map of flash messages to display"
  attr :title, :string, default: nil
  attr :kind, :atom, values: [:info, :error], doc: "used for styling and flash lookup"
  attr :rest, :global, doc: "the arbitrary HTML attributes to add to the flash container"

  slot :inner_block, doc: "the optional inner block that renders the flash message"

  def flash(assigns) do
    assigns = assign_new(assigns, :id, fn -> "flash-#{assigns.kind}" end)

    ~H"""
    <div
      :if={msg = render_slot(@inner_block) || Phoenix.Flash.get(@flash, @kind)}
      id={@id}
      phx-click={JS.push("lv:clear-flash", value: %{key: @kind}) |> hide("##{@id}")}
      role="alert"
      class="toast toast-top toast-end z-50"
      {@rest}
    >
      <div class={[
        "alert w-80 sm:w-96 max-w-80 sm:max-w-96 text-wrap",
        @kind == :info && "alert-info",
        @kind == :error && "alert-error"
      ]}>
        <.icon :if={@kind == :info} name="hero-information-circle" class="size-5 shrink-0" />
        <.icon :if={@kind == :error} name="hero-exclamation-circle" class="size-5 shrink-0" />
        <div>
          <p :if={@title} class="font-semibold">{@title}</p>
          <p>{msg}</p>
        </div>
        <div class="flex-1" />
        <button type="button" class="group self-start cursor-pointer" aria-label="close">
          <.icon name="hero-x-mark" class="size-5 opacity-40 group-hover:opacity-70" />
        </button>
      </div>
    </div>
    """
  end

  @doc """
  Renders a button with navigation support.

  ## Examples

      <.button>Send!</.button>
      <.button phx-click="go" variant="primary">Send!</.button>
      <.button navigate={~p"/"}>Home</.button>
  """
  attr :rest, :global, include: ~w(href navigate patch method download name value disabled)
  attr :class, :string
  attr :variant, :string, values: ~w(primary)
  slot :inner_block, required: true

  def button(%{rest: rest} = assigns) do
    variants = %{"primary" => "btn-primary", nil => "btn-primary btn-soft"}

    assigns =
      assign_new(assigns, :class, fn ->
        ["btn", Map.fetch!(variants, assigns[:variant])]
      end)

    if rest[:href] || rest[:navigate] || rest[:patch] do
      ~H"""
      <.link class={@class} {@rest}>
        {render_slot(@inner_block)}
      </.link>
      """
    else
      ~H"""
      <button class={@class} {@rest}>
        {render_slot(@inner_block)}
      </button>
      """
    end
  end

  @doc """
  Renders an input with label and error messages.

  A `Phoenix.HTML.FormField` may be passed as argument,
  which is used to retrieve the input name, id, and values.
  Otherwise all attributes may be passed explicitly.

  ## Types

  This function accepts all HTML input types, considering that:

    * You may also set `type="select"` to render a `<select>` tag

    * `type="checkbox"` is used exclusively to render boolean values

    * For live file uploads, see `Phoenix.Component.live_file_input/1`

  See https://developer.mozilla.org/en-US/docs/Web/HTML/Element/input
  for more information. Unsupported types, such as hidden and radio,
  are best written directly in your templates.

  ## Examples

      <.input field={@form[:email]} type="email" />
      <.input name="my-input" errors={["oh no!"]} />
  """
  attr :id, :any, default: nil
  attr :name, :any
  attr :label, :string, default: nil
  attr :value, :any

  attr :type, :string,
    default: "text",
    values: ~w(checkbox color date datetime-local email file month number password
               search select tel text textarea time url week)

  attr :field, Phoenix.HTML.FormField,
    doc: "a form field struct retrieved from the form, for example: @form[:email]"

  attr :errors, :list, default: []
  attr :checked, :boolean, doc: "the checked flag for checkbox inputs"
  attr :prompt, :string, default: nil, doc: "the prompt for select inputs"
  attr :options, :list, doc: "the options to pass to Phoenix.HTML.Form.options_for_select/2"
  attr :multiple, :boolean, default: false, doc: "the multiple flag for select inputs"
  attr :class, :string, default: nil, doc: "the input class to use over defaults"
  attr :error_class, :string, default: nil, doc: "the input error class to use over defaults"

  attr :rest, :global,
    include: ~w(accept autocomplete capture cols disabled form list max maxlength min minlength
                multiple pattern placeholder readonly required rows size step)

  def input(%{field: %Phoenix.HTML.FormField{} = field} = assigns) do
    errors = if Phoenix.Component.used_input?(field), do: field.errors, else: []

    assigns
    |> assign(field: nil, id: assigns.id || field.id)
    |> assign(:errors, Enum.map(errors, &translate_error(&1)))
    |> assign_new(:name, fn -> if assigns.multiple, do: field.name <> "[]", else: field.name end)
    |> assign_new(:value, fn -> field.value end)
    |> input()
  end

  def input(%{type: "checkbox"} = assigns) do
    assigns =
      assign_new(assigns, :checked, fn ->
        Phoenix.HTML.Form.normalize_value("checkbox", assigns[:value])
      end)

    ~H"""
    <div class="fieldset mb-2">
      <label>
        <input type="hidden" name={@name} value="false" disabled={@rest[:disabled]} />
        <span class="label">
          <input
            type="checkbox"
            id={@id}
            name={@name}
            value="true"
            checked={@checked}
            class={@class || "checkbox checkbox-sm"}
            {@rest}
          />{@label}
        </span>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "select"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <select
          id={@id}
          name={@name}
          class={[@class || "w-full select", @errors != [] && (@error_class || "select-error")]}
          multiple={@multiple}
          {@rest}
        >
          <option :if={@prompt} value="">{@prompt}</option>
          {Phoenix.HTML.Form.options_for_select(@options, @value)}
        </select>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  def input(%{type: "textarea"} = assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <textarea
          id={@id}
          name={@name}
          class={[
            @class || "w-full textarea",
            @errors != [] && (@error_class || "textarea-error")
          ]}
          {@rest}
        >{Phoenix.HTML.Form.normalize_value("textarea", @value)}</textarea>
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # All other inputs text, datetime-local, url, password, etc. are handled here...
  def input(assigns) do
    ~H"""
    <div class="fieldset mb-2">
      <label>
        <span :if={@label} class="label mb-1">{@label}</span>
        <input
          type={@type}
          name={@name}
          id={@id}
          value={Phoenix.HTML.Form.normalize_value(@type, @value)}
          class={[
            @class || "w-full input",
            @errors != [] && (@error_class || "input-error")
          ]}
          {@rest}
        />
      </label>
      <.error :for={msg <- @errors}>{msg}</.error>
    </div>
    """
  end

  # Helper used by inputs to generate form errors
  defp error(assigns) do
    ~H"""
    <p class="mt-1.5 flex gap-2 items-center text-sm text-error">
      <.icon name="hero-exclamation-circle" class="size-5" />
      {render_slot(@inner_block)}
    </p>
    """
  end

  @doc """
  Renders a header with title.
  """
  slot :inner_block, required: true
  slot :subtitle
  slot :actions

  def header(assigns) do
    ~H"""
    <header class={[@actions != [] && "flex items-center justify-between gap-6", "pb-4"]}>
      <div>
        <h1 class="text-lg font-semibold leading-8">
          {render_slot(@inner_block)}
        </h1>
        <p :if={@subtitle != []} class="text-sm text-base-content/70">
          {render_slot(@subtitle)}
        </p>
      </div>
      <div class="flex-none">{render_slot(@actions)}</div>
    </header>
    """
  end

  @doc """
  Renders a modal.

  ## Examples

      <.modal id="confirm-modal">
        This is a modal.
      </<.modal>

  JS commands may be passed to the `:on_cancel` to configure
  the closing/cancel event, for example:

      <.modal id="confirm" on_cancel={JS.navigate(~p"/posts")}>
        This is another modal.
      </<.modal>

  """
  attr :id, :string, required: true
  attr :show, :boolean, default: false
  attr :on_cancel, JS, default: %JS{}
  slot :inner_block, required: true

  def modal(assigns) do
    ~H"""
    <div
      id={@id}
      phx-mounted={@show && show_modal(@id)}
      phx-remove={hide_modal(@id)}
      data-cancel={JS.exec(@on_cancel, "phx-remove")}
      class="relative z-50 hidden"
    >
      <div
        id={"#{@id}-bg"}
        class="bg-zinc-950/90 fixed inset-0 transition-opacity"
        aria-hidden="true"
      />
      <div
        class="fixed inset-0 overflow-y-auto"
        aria-labelledby={"#{@id}-title"}
        aria-describedby={"#{@id}-description"}
        role="dialog"
        aria-modal="true"
        tabindex="0"
      >
        <div class="flex min-h-full items-center justify-center">
          <div class="w-full max-w-3xl p-4 sm:p-6 lg:py-8">
            <.focus_wrap
              id={"#{@id}-container"}
              phx-window-keydown={JS.exec("data-cancel", to: "##{@id}")}
              phx-key="escape"
              phx-click-away={JS.exec("data-cancel", to: "##{@id}")}
              class="shadow-zinc-700/10 ring-zinc-700/10 relative hidden rounded-2xl bg-white p-14 shadow-lg ring-1 transition"
            >
              <div class="absolute top-6 right-5">
                <button
                  phx-click={JS.exec("data-cancel", to: "##{@id}")}
                  type="button"
                  class="-m-3 flex-none p-3 opacity-20 hover:opacity-40"
                  aria-label="close"
                >
                  <.icon name="hero-x-mark-solid" class="size-5" />
                </button>
              </div>
              <div id={"#{@id}-content"}>
                {render_slot(@inner_block)}
              </div>
            </.focus_wrap>
          </div>
        </div>
      </div>
    </div>
    """
  end

  @doc """
  Renders a table with generic styling.

  ## Examples

      <.table id="users" rows={@users}>
        <:col :let={user} label="id">{user.id}</:col>
        <:col :let={user} label="username">{user.username}</:col>
      </.table>
  """
  attr :id, :string, required: true
  attr :rows, :list, required: true
  attr :row_id, :any, default: nil, doc: "the function for generating the row id"
  attr :row_click, :any, default: nil, doc: "the function for handling phx-click on each row"

  attr :row_item, :any,
    default: &Function.identity/1,
    doc: "the function for mapping each row before calling the :col and :action slots"

  slot :col, required: true do
    attr :label, :string
  end

  slot :action, doc: "the slot for showing user actions in the last table column"

  def table(assigns) do
    assigns =
      with %{rows: %Phoenix.LiveView.LiveStream{}} <- assigns do
        assign(assigns, row_id: assigns.row_id || fn {id, _item} -> id end)
      end

    ~H"""
    <table class="table table-zebra">
      <thead>
        <tr>
          <th :for={col <- @col}>{col[:label]}</th>
          <th :if={@action != []}>
            <span class="sr-only">Actions</span>
          </th>
        </tr>
      </thead>
      <tbody id={@id} phx-update={is_struct(@rows, Phoenix.LiveView.LiveStream) && "stream"}>
        <tr :for={row <- @rows} id={@row_id && @row_id.(row)}>
          <td
            :for={col <- @col}
            phx-click={@row_click && @row_click.(row)}
            class={@row_click && "hover:cursor-pointer"}
          >
            {render_slot(col, @row_item.(row))}
          </td>
          <td :if={@action != []} class="w-0 font-semibold">
            <div class="flex gap-4">
              <%= for action <- @action do %>
                {render_slot(action, @row_item.(row))}
              <% end %>
            </div>
          </td>
        </tr>
      </tbody>
    </table>
    """
  end

  @doc """
  Renders a data list.

  ## Examples

      <.list>
        <:item title="Title">{@post.title}</:item>
        <:item title="Views">{@post.views}</:item>
      </.list>
  """
  slot :item, required: true do
    attr :title, :string, required: true
  end

  def list(assigns) do
    ~H"""
    <ul class="list">
      <li :for={item <- @item} class="list-row">
        <div class="list-col-grow">
          <div class="font-bold">{item.title}</div>
          <div>{render_slot(item)}</div>
        </div>
      </li>
    </ul>
    """
  end

  @doc """
  Renders a [Heroicon](https://heroicons.com).

  Heroicons come in three styles – outline, solid, and mini.
  By default, the outline style is used, but solid and mini may
  be applied by using the `-solid` and `-mini` suffix.

  You can customize the size and colors of the icons by setting
  width, height, and background color classes.

  Icons are extracted from the `deps/heroicons` directory and bundled within
  your compiled app.css by the plugin in `assets/vendor/heroicons.js`.

  ## Examples

      <.icon name="hero-x-mark" />
      <.icon name="hero-arrow-path" class="ml-1 size-3 motion-safe:animate-spin" />
  """
  attr :name, :string, required: true
  attr :class, :string, default: "size-4"

  def icon(%{name: "hero-" <> _} = assigns) do
    ~H"""
    <span class={[@name, @class]} />
    """
  end

  ## JS Commands

  def show(js \\ %JS{}, selector) do
    JS.show(js,
      to: selector,
      time: 300,
      transition:
        {"transition-all ease-out duration-300",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95",
         "opacity-100 translate-y-0 sm:scale-100"}
    )
  end

  def show_modal(js \\ %JS{}, id) when is_binary(id) do
    js
    |> JS.show(to: "##{id}")
    |> JS.show(
      to: "##{id}-bg",
      time: 300,
      transition: {"transition-all ease-out duration-300", "opacity-0", "opacity-100"}
    )
    |> show("##{id}-container")
    |> JS.add_class("overflow-hidden", to: "body")
    |> JS.focus_first(to: "##{id}-content")
  end

  def hide_modal(js \\ %JS{}, id) do
    js
    |> JS.hide(
      to: "##{id}-bg",
      transition: {"transition-all ease-in duration-200", "opacity-100", "opacity-0"}
    )
    |> hide("##{id}-container")
    |> JS.hide(to: "##{id}", transition: {"block", "block", "hidden"})
    |> JS.remove_class("overflow-hidden", to: "body")
    |> JS.pop_focus()
  end

  def hide(js \\ %JS{}, selector) do
    JS.hide(js,
      to: selector,
      time: 200,
      transition:
        {"transition-all ease-in duration-200", "opacity-100 translate-y-0 sm:scale-100",
         "opacity-0 translate-y-4 sm:translate-y-0 sm:scale-95"}
    )
  end

  @doc """
  Translates an error message using gettext.
  """
  def translate_error({msg, opts}) do
    # You can make use of gettext to translate error messages by
    # uncommenting and adjusting the following code:

    # if count = opts[:count] do
    #   Gettext.dngettext(MykonosBiennaleWeb.Gettext, "errors", msg, msg, count, opts)
    # else
    #   Gettext.dgettext(MykonosBiennaleWeb.Gettext, "errors", msg, opts)
    # end

    Enum.reduce(opts, msg, fn {key, value}, acc ->
      String.replace(acc, "%{#{key}}", fn _ -> to_string(value) end)
    end)
  end

  @doc """
  Translates the errors for a field from a keyword list of errors.
  """
  def translate_errors(errors, field) when is_list(errors) do
    for {^field, {msg, opts}} <- errors, do: translate_error({msg, opts})
  end

  attr :entity, :any, required: true
  attr :cancel_path, :string, required: true

  def entity_detail(assigns) do
    ~H"""
    <div data-theme="light" class="bg-white rounded-xl p-6 max-h-[80vh] overflow-y-auto">
      <div class="flex items-center justify-between mb-6">
        <h2 class="text-xl font-bold text-gray-900">
          {@entity.identity || "Entity ##{@entity.id}"}
        </h2>
        <.link patch={@cancel_path} class="text-gray-400 hover:text-gray-600">
          <.icon name="hero-x-mark" class="w-5 h-5" />
        </.link>
      </div>

      <div class="space-y-4">
        <div class="grid grid-cols-2 gap-4 text-sm">
          <div>
            <span class="font-semibold text-gray-500">ID</span>
            <div class="text-gray-900">{@entity.id}</div>
          </div>
          <div>
            <span class="font-semibold text-gray-500">Type</span>
            <div class="text-gray-900">{@entity.type}</div>
          </div>
          <div>
            <span class="font-semibold text-gray-500">Slug</span>
            <div class="text-gray-900">{@entity.slug}</div>
          </div>
          <div>
            <span class="font-semibold text-gray-500">Visible</span>
            <div class="text-gray-900">{@entity.visible}</div>
          </div>
        </div>

        <div>
          <h3 class="text-sm font-semibold text-gray-500 mb-2">Fields</h3>
          <pre class="bg-gray-50 rounded-lg p-4 text-xs text-gray-800 overflow-x-auto whitespace-pre-wrap break-words">{format_fields(@entity.fields)}</pre>
        </div>
      </div>
    </div>
    """
  end

  defp format_fields(fields) when is_map(fields) do
    fields
    |> Enum.sort_by(fn {k, _} -> to_string(k) end)
    |> Enum.map(fn {k, v} -> format_field(k, v) end)
    |> Enum.join("\n")
  end

  defp format_fields(_), do: "(empty)"

  defp format_field(key, value) when is_map(value) do
    formatted = format_fields(value)
    "#{key}:\n  #{String.replace(formatted, "\n", "\n  ")}"
  end

  defp format_field(key, value) when is_list(value) do
    "#{key}: #{inspect(value)}"
  end

  defp format_field(key, value) do
    "#{key}: #{inspect(value)}"
  end

  attr :artwork, :any, required: true
  attr :media, :list, default: nil
  attr :creators, :list, default: nil
  attr :show_creators, :boolean, default: true
  attr :show_description, :boolean, default: false
  attr :show_statement, :boolean, default: false
@doc """
  Renders a responsive `<picture>` element with AVIF, WebP sources, and JPEG fallback.

  Browsers negotiate the best format they support: AVIF (best compression),
  WebP (wide support), or fall back to the original file (JPEG/PNG).

  Pass either a `media` struct (preferred) or individual URL attributes.
  """
  attr :record, :map, default: nil
  attr :size, :string, default: "card"
  attr :avif, :string, default: nil
  attr :webp, :string, default: nil
  attr :original, :string, default: nil
  attr :alt, :string, default: ""
  attr :class, :string, default: "w-full h-full object-cover"

  def picture(%{record: media} = assigns) when not is_nil(media) and media != %{} do
    assigns =
      assigns
      |> assign(:avif_url, MykonosBiennale.Uploads.media_url(media, size: assigns[:size], format: "avif"))
      |> assign(:webp_url, MykonosBiennale.Uploads.media_url(media, size: assigns[:size], format: "webp"))
      |> assign(:jpg_url, MykonosBiennale.Uploads.media_url(media, size: assigns[:size], format: "jpg"))

    ~H"""
    <picture>
      <source :if={@avif_url} type="image/avif" srcset={@avif_url} />
      <source :if={@webp_url} type="image/webp" srcset={@webp_url} />
      <img src={@jpg_url} alt={@alt} class={@class} loading="lazy" />
    </picture>
    """
  end

  def picture(assigns) do
    ~H"""
    <picture>
      <source :if={@avif} type="image/avif" srcset={@avif} />
      <source :if={@webp} type="image/webp" srcset={@webp} />
      <img src={@original} alt={@alt} class={@class} loading="lazy" />
    </picture>
    """
  end

  attr :show_edit_link, :boolean, default: false
  attr :class, :string, default: ""

  def artwork_card(assigns) do
    artwork = assigns[:artwork]
    resolved_media = assigns[:media] || MykonosBiennale.Content.list_media_for_entity(artwork)
    resolved_creators = assigns[:creators] || resolve_artwork_creators(artwork)
    assigns = assign(assigns, :resolved_media, resolved_media)

    assigns =
      assign(
        assigns,
        :resolved_creators,
        if(assigns[:show_creators], do: resolved_creators, else: [])
      )

    ~H"""
    <div class={"card bg-base-100 shadow-sm border border-base-300 #{@class}"}>
      <figure class="bg-base-200 aspect-video flex items-center justify-center">
        <%= case first_image(@resolved_media) do %>
          <% %{source_type: "upload", source_path: _path} = media -> %>
            <.picture record={media} size="card" alt={artwork_field(@artwork, "title")} />
          <% %{source_type: "url", source_url: url} -> %>
            <img src={url} alt={artwork_field(@artwork, "title")} class="w-full h-full object-cover" />
          <% _ -> %>
            <.icon name="hero-photo" class="w-12 h-12 text-base-300" />
        <% end %>
      </figure>
      <div class="card-body p-4 gap-2">
        <h3 class="card-title text-base">
          {artwork_field(@artwork, "title", "Untitled")}
        </h3>
        <%= if @resolved_creators != [] do %>
          <div class="text-sm text-base-content/50">
            <%= for {creator, idx} <- Enum.with_index(@resolved_creators) do %>
              <.link patch={"/admin/participants/#{creator.id}"} class="hover:text-base-content/70">
                {artwork_field(creator, "name")}
              </.link>
              <%= if idx < length(@resolved_creators) - 1 do %>
                ,
              <% end %>
            <% end %>
          </div>
        <% end %>
        <div class="flex flex-wrap gap-x-3 gap-y-1 text-xs text-base-content/60">
          <span :if={artwork_field(@artwork, "date")}>{artwork_field(@artwork, "date")}</span>
          <span :if={artwork_field(@artwork, "size")}>{artwork_field(@artwork, "size")}</span>
          <span :if={artwork_field(@artwork, "medium")}>{artwork_field(@artwork, "medium")}</span>
        </div>
        <p
          :if={@show_description && artwork_field(@artwork, "description")}
          class="text-sm text-base-content/70 line-clamp-3 mt-1"
        >
          {artwork_field(@artwork, "description")}
        </p>
        <p
          :if={@show_statement && artwork_field(@artwork, "statement")}
          class="text-sm text-base-content/70 line-clamp-3 mt-1"
        >
          {artwork_field(@artwork, "statement")}
        </p>
        <div :if={@show_edit_link} class="card-actions justify-end mt-2">
          <.link
            patch={"/admin/artworks/#{@artwork.id}/edit"}
            class="btn btn-sm btn-ghost"
          >
            Edit
          </.link>
        </div>
      </div>
    </div>
    """
  end

  defp artwork_field(entity, key, default \\ nil)

  defp artwork_field(%{fields: fields}, key, default) when is_map(fields) do
    Map.get(fields, to_string(key), Map.get(fields, key, default))
  end

  defp artwork_field(_, _key, default), do: default

  defp resolve_artwork_creators(artwork) do
    MykonosBiennale.Content.Artwork.list_linked_participants(artwork)
    |> Enum.map(& &1.object)
    |> Enum.reject(&is_nil/1)
  end

  defp first_image([]), do: nil

  defp first_image([media | _]) do
    case media.source_type do
      "upload" when is_binary(media.source_path) -> media
      "url" when is_binary(media.source_url) -> media
      _ -> first_image([])
    end
  end

  defp first_image(_), do: nil

  attr :base_path, :string, required: true
  attr :sort_by, :atom, required: true
  attr :current_sort, :atom, default: nil
  attr :current_dir, :atom, default: nil
  attr :class, :string, default: ""

  def sort_header(assigns) do
    ~H"""
    <.link patch={sort_url(@base_path, @sort_by, @current_sort, @current_dir)} class={"cursor-pointer select-none inline-flex items-center gap-0.5 #{@class}"}>
      {render_slot(@inner_block)}
      <%= if @current_sort == @sort_by do %>
        <.icon name={if @current_dir == :asc, do: "hero-chevron-up", else: "hero-chevron-down"} class="w-3 h-3" />
      <% end %>
    </.link>
    """
  end

  defp sort_url(base_path, sort_by, current_sort, current_dir) do
    dir = if current_sort == sort_by and current_dir == :asc, do: :desc, else: :asc
    "#{base_path}?#{URI.encode_query(%{page: 1, sort_by: sort_by, sort_dir: dir})}"
  end

  attr :current_page, :integer, required: true
  attr :total_pages, :integer, required: true
  attr :total_count, :integer, default: nil
  attr :base_path, :string, required: true
  attr :sort_by, :atom, default: nil
  attr :sort_dir, :atom, default: nil

  def pagination(assigns) do
    ~H"""
    <nav class="flex items-center justify-between px-1 py-1.5 mt-2" aria-label="Pagination">
      <div class="hidden sm:flex-1 sm:flex sm:items-center sm:justify-between">
        <p class="text-xs text-gray-700 dark:text-gray-300">
          Page <span class="font-medium"><%= @current_page %></span> of <span class="font-medium"><%= @total_pages %></span><%= if @total_count do %>, <%= @total_count %> records<% end %>
        </p>
        <div>
          <nav class="relative z-0 inline-flex rounded-md shadow-sm -space-x-px" aria-label="Pagination">
            <%= if @current_page > 1 do %>
              <.link patch={page_url(@base_path, @current_page - 1, assigns)} class="relative inline-flex items-center px-1.5 py-1 rounded-l-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-sm font-medium text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700">
                <span class="sr-only">Previous</span>
                <.icon name="hero-chevron-left" class="w-4 h-4" />
              </.link>
            <% else %>
              <span class="relative inline-flex items-center px-1.5 py-1 rounded-l-md border border-gray-300 dark:border-gray-600 bg-gray-100 dark:bg-gray-900 text-sm font-medium text-gray-400 dark:text-gray-600 cursor-not-allowed">
                <span class="sr-only">Previous</span>
                <.icon name="hero-chevron-left" class="w-4 h-4" />
              </span>
            <% end %>

            <%= for page <- page_range(@current_page, @total_pages) do %>
              <%= if page == :ellipsis do %>
                <span class="relative inline-flex items-center px-3 py-1 border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-xs font-medium text-gray-700 dark:text-gray-300">…</span>
              <% else %>
                <.link patch={page_url(@base_path, page, assigns)} class={"relative inline-flex items-center px-3 py-1 border text-xs font-medium #{if page == @current_page, do: "z-10 border-blue-500 dark:border-blue-400 bg-blue-50 dark:bg-blue-900 text-blue-600 dark:text-blue-200", else: "border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700"}"}>
                  <%= page %>
                </.link>
              <% end %>
            <% end %>

            <%= if @current_page < @total_pages do %>
              <.link patch={page_url(@base_path, @current_page + 1, assigns)} class="relative inline-flex items-center px-1.5 py-1 rounded-r-md border border-gray-300 dark:border-gray-600 bg-white dark:bg-gray-800 text-sm font-medium text-gray-500 dark:text-gray-400 hover:bg-gray-50 dark:hover:bg-gray-700">
                <span class="sr-only">Next</span>
                <.icon name="hero-chevron-right" class="w-4 h-4" />
              </.link>
            <% else %>
              <span class="relative inline-flex items-center px-1.5 py-1 rounded-r-md border border-gray-300 dark:border-gray-600 bg-gray-100 dark:bg-gray-900 text-sm font-medium text-gray-400 dark:text-gray-600 cursor-not-allowed">
                <span class="sr-only">Next</span>
                <.icon name="hero-chevron-right" class="w-4 h-4" />
              </span>
            <% end %>
          </nav>
        </div>
      </div>

      <div class="flex items-center justify-between sm:hidden w-full">
        <%= if @current_page > 1 do %>
          <.link patch={page_url(@base_path, @current_page - 1, assigns)} class="relative inline-flex items-center px-3 py-1 border border-gray-300 dark:border-gray-600 text-xs font-medium rounded-md bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700">
            Previous
          </.link>
        <% else %>
          <span class="relative inline-flex items-center px-3 py-1 border border-gray-300 dark:border-gray-600 text-xs font-medium rounded-md bg-gray-100 dark:bg-gray-900 text-gray-400 dark:text-gray-600 cursor-not-allowed">
            Previous
          </span>
        <% end %>
        <span class="text-xs text-gray-700 dark:text-gray-300"><%= @current_page %> / <%= @total_pages %></span>
        <%= if @current_page < @total_pages do %>
          <.link patch={page_url(@base_path, @current_page + 1, assigns)} class="relative inline-flex items-center px-3 py-1 border border-gray-300 dark:border-gray-600 text-xs font-medium rounded-md bg-white dark:bg-gray-800 text-gray-700 dark:text-gray-300 hover:bg-gray-50 dark:hover:bg-gray-700">
            Next
          </.link>
        <% else %>
          <span class="relative inline-flex items-center px-3 py-1 border border-gray-300 dark:border-gray-600 text-xs font-medium rounded-md bg-gray-100 dark:bg-gray-900 text-gray-400 dark:text-gray-600 cursor-not-allowed">
            Next
          </span>
        <% end %>
      </div>
    </nav>
    """
  end

  defp page_url(base_path, page, assigns) do
    params = %{page: page}
    params = if assigns[:sort_by], do: Map.put(params, :sort_by, assigns.sort_by), else: params
    params = if assigns[:sort_dir], do: Map.put(params, :sort_dir, assigns.sort_dir), else: params
    "#{base_path}?#{URI.encode_query(params)}"
  end

  defp page_range(current, total) when total <= 7 do
    Enum.to_list(1..total)
  end

  defp page_range(current, total) do
    cond do
      current <= 3 -> [1, 2, 3, 4, :ellipsis, total]
      current >= total - 2 -> [1, :ellipsis, total - 3, total - 2, total - 1, total]
      true -> [1, :ellipsis, current - 1, current, current + 1, :ellipsis, total]
    end
  end
end
