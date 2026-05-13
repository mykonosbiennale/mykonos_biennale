defmodule MykonosBiennaleWeb.BiennaleHTML do
  use MykonosBiennaleWeb, :html

  embed_templates "biennale_html/*"

  def media_url(%{source_type: "upload", source_path: path}) when is_binary(path), do: "/uploads/#{path}"
  def media_url(%{source_type: "url", source_url: url}) when is_binary(url), do: url
  def media_url(_), do: nil

  def format_date(nil), do: nil
  def format_date(date) when is_binary(date) do
    case Date.from_iso8601(date) do
      {:ok, d} -> Calendar.strftime(d, "%B %d, %Y")
      _ -> date
    end
  end
  def format_date(%Date{} = d), do: Calendar.strftime(d, "%B %d, %Y")
end