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
        |> Enum.map(&String.capitalize/1)
        |> Enum.join(" ")

      {label, name}
    end
    |> Enum.sort_by(fn {label, _} -> label end)
  )

  def template_options, do: @system_templates ++ @discovered_templates

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
        display_hour = if hour > 12, do: hour - 12, else: if hour == 0, do: 12, else: hour
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
