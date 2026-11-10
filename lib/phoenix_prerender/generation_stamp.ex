defmodule PhoenixPrerender.GenerationStamp do
  @moduledoc false

  @stamp_file ".generation_stamp"

  def read(output_path) do
    case File.read(Path.join(output_path, @stamp_file)) do
      {:ok, stamp} -> String.trim(stamp)
      {:error, _} -> nil
    end
  end

  def write!(output_path) do
    File.mkdir_p!(output_path)
    File.write!(Path.join(output_path, @stamp_file), DateTime.utc_now() |> DateTime.to_iso8601())
  end
end
