defmodule MykonosBiennaleWeb.PageHTML do
  @moduledoc """
  This module contains pages rendered by PageController.

  See the `page_html` directory for all templates available.
  """
  use MykonosBiennaleWeb, :html

  embed_templates "page_html/*"

  def media_url(%{source_type: "upload", source_path: path}) when is_binary(path),
    do: "/uploads/#{path}"

  def media_url(%{source_type: "url", source_url: url}) when is_binary(url), do: url
  def media_url(_), do: nil
end
