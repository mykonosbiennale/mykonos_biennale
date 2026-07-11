defmodule MykonosBiennaleTest.LogFilter do
  @moduledoc false

  def filter(log_event, _opts) do
    msg = log_event[:msg]

    str =
      case msg do
        {:string, s} -> to_string(s)
        {:report, %{msg: m}} when is_binary(m) -> m
        {:report, %{message: m}} when is_binary(m) -> m
        {:report, r} -> inspect(r)
        _ -> inspect(msg)
      end

    if String.contains?(str, "disconnected") and
         String.contains?(str, "DBConnection.ConnectionError") do
      :stop
    else
      :ignore
    end
  end
end
