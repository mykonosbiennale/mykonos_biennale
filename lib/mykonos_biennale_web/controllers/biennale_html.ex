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

  @build_env (case Mix.env() do
                :prod -> "P"
                :test -> "T"
                _ -> "D"
              end)

  def build_label(render_mode) do
    "#{MykonosBiennale.Application.project_version()} · #{@build_env} · #{render_mode}"
  end

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
        "#{display_hour(hour)}:#{m} #{suffix}"

      _ ->
        time
    end
  end

  defp display_hour(hour) when hour > 12, do: hour - 12
  defp display_hour(0), do: 12
  defp display_hour(hour), do: hour

  def format_day(nil), do: nil

  def format_day(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> Calendar.strftime(d, "%A, %d/%m")
      _ -> date
    end
  end

  def render_content(nil, _assigns), do: Phoenix.HTML.raw("")

  # Page content is stored HTML written by admins. It is output as-is and is
  # never evaluated as a template.
  def render_content(content, _assigns) when is_binary(content), do: Phoenix.HTML.raw(content)
end
