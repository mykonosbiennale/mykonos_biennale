defmodule MykonosBiennaleWeb.BiennaleHTML do
  use MykonosBiennaleWeb, :html

  embed_templates "biennale_html/*"

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