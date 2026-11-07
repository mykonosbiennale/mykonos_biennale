defmodule MykonosBiennaleWeb.BiennaleHTML do
  use MykonosBiennaleWeb, :html

  embed_templates "biennale_html/*"

  @system_templates [{"Default", "default"}, {"None (raw content)", "none"}]

  @discovered_templates (
                          dir = Path.join(__DIR__, "biennale_html")

                          for path <- Path.wildcard(Path.join(dir, "*.html.heex")),
                              name = Path.basename(path, ".html.heex"),
                              name not in ["biennale", "none"] do
                            label =
                              name
                              |> String.replace("-", " ")
                              |> String.replace("_", " ")
                              |> String.split(" ")
                              |> Enum.map_join(" ", &String.capitalize/1)

                            {label, name}
                          end
                          |> Enum.sort_by(fn {label, _} -> label end)
                        )

  def template_options, do: @system_templates ++ @discovered_templates

  attr :title, :string, required: true
  attr :names, :list, required: true
  attr :border, :string, required: true
  attr :text, :string, required: true

  def summary_section(assigns) do
    ~H"""
    <div :if={@names != []} class={["border-l-4 pl-6", @border]}>
      <h2 class={["text-xl md:text-2xl font-bold uppercase tracking-wider mb-4", @text]}>
        {@title}
      </h2>
      <p class="text-sm md:text-base text-gray-300 leading-relaxed">
        {Enum.join(@names, " · ")}
      </p>
    </div>
    """
  end

  attr :biennales, :list, required: true
  attr :media_map, :map, required: true

  def archive_teaser(assigns) do
    tiles =
      assigns.biennales
      |> Enum.reject(&(&1.fields["template"] == "summary"))
      |> Enum.map(fn biennale ->
        bg =
          case Map.get(assigns.media_map, biennale.id, []) do
            [first | _] ->
              "background-image: url('#{media_url(first, size: :thumb)}'); background-size: cover; background-position: center;"

            [] ->
              ""
          end

        {biennale, bg}
      end)

    assigns = assign(assigns, :tiles, tiles)

    ~H"""
    <div class="px-6 py-16 md:py-24 bg-neutral-950">
      <div class="max-w-5xl mx-auto">
        <h2 class="text-3xl md:text-4xl font-bold uppercase mb-10 text-center">Archive</h2>

        <div class="flex flex-wrap justify-center gap-2">
          <a
            :for={{biennale, bg} <- @tiles}
            href={~p"/biennale/#{biennale.slug}"}
            class="aspect-square w-20 sm:w-24 md:w-28 bg-black border border-gray-800 flex items-center justify-center hover:bg-gray-900 transition-colors relative overflow-hidden"
            style={bg}
          >
            <div class="absolute inset-0 bg-black/30"></div>
            <div class="relative text-center">
              <span class="block text-lg font-bold text-red-700 hover:text-red-500 transition-colors">
                {biennale.fields["year"]}
              </span>
              <span class="block text-[10px] font-bold text-red-700 leading-tight mt-0.5">
                {biennale.fields["theme"]}
              </span>
            </div>
          </a>
        </div>

        <div :if={length(@tiles) > 8} class="text-center mt-10">
          <a
            href={~p"/archive"}
            class="px-8 py-4 border-2 border-white text-white font-bold uppercase tracking-wider hover:bg-white hover:text-black transition-colors inline-block"
          >
            View All Editions
          </a>
        </div>
      </div>
    </div>
    """
  end

  def media_url(media, opts \\ [])
  def media_url(media, opts), do: MykonosBiennale.Uploads.media_url(media, opts)

  def format_date(nil), do: nil

  def format_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> Calendar.strftime(d, "%B %d, %Y")
      _ -> date
    end
  end

  def format_date(%Date{} = d), do: Calendar.strftime(d, "%B %d, %Y")

  def format_time(nil), do: nil

  def format_time(time) when is_binary(time) do
    case String.split(time, ":") do
      [h, m] ->
        {hour, ""} = Integer.parse(h)

        suffix = if hour >= 12, do: "PM", else: "AM"
        display_hour = if hour > 12, do: hour - 12, else: if(hour == 0, do: 12, else: hour)
        "#{display_hour}:#{m} #{suffix}"

      _ ->
        time
    end
  end

  def format_day(nil), do: nil

  def format_day(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> Calendar.strftime(d, "%A, %d/%m")
      _ -> date
    end
  end

  def render_content(nil, _assigns), do: Phoenix.HTML.raw("")

  def render_content(content, assigns) when is_binary(content) and is_map(assigns) do
    ast =
      EEx.compile_string(content,
        engine: Phoenix.LiveView.TagEngine,
        line: 1,
        file: "biennale_content",
        trim: true,
        caller: caller_env(),
        source: content,
        tag_handler: Phoenix.LiveView.HTMLEngine
      )

    {rendered, _} = Code.eval_quoted(ast, [assigns: assigns], caller_env())

    html =
      rendered
      |> render_to_iodata()
      |> IO.iodata_to_binary()

    Phoenix.HTML.raw(strip_debug_annotations(html))
  rescue
    _ ->
      Phoenix.HTML.raw(content)
  end

  defp caller_env do
    env = __ENV__
    %{env | file: "biennale_content", line: 1}
  end

  defp render_to_iodata(%Phoenix.LiveView.Rendered{static: static, dynamic: dynamic})
       when is_function(dynamic, 1) do
    parts = dynamic.(nil)
    interleave(static, parts)
  end

  defp render_to_iodata(%Phoenix.LiveView.Rendered{static: static, dynamic: nil}), do: static
  defp render_to_iodata(iodata) when is_list(iodata), do: iodata
  defp render_to_iodata(binary) when is_binary(binary), do: binary

  defp interleave([static_part | rest_static], [dynamic_part | rest_dynamic]) do
    [static_part | [render_to_iodata(dynamic_part) | interleave(rest_static, rest_dynamic)]]
  end

  defp interleave([static_part], []), do: [static_part]
  defp interleave([], []), do: []

  defp strip_debug_annotations(html) do
    Regex.replace(~r/<!--\s*<\/?[\w.]+>\s*[^-]*?-->/, html, "")
  end
end
