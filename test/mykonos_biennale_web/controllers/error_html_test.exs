defmodule MykonosBiennaleWeb.ErrorHTMLTest do
  use ExUnit.Case, async: true

  alias MykonosBiennaleWeb.ErrorHTML

  test "renders the status message for known error templates" do
    assert ErrorHTML.render("404.html", %{}) == "Not Found"
    assert ErrorHTML.render("500.html", %{}) == "Internal Server Error"
  end

  test "falls back to the status message for any other status template" do
    assert ErrorHTML.render("403.html", %{}) == "Forbidden"
  end
end
