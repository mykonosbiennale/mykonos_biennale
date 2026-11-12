defmodule PhoenixPrerender.GenerationStampTest do
  use ExUnit.Case, async: true

  alias PhoenixPrerender.GenerationStamp

  setup do
    dir = Path.join(System.tmp_dir!(), "gen_stamp_#{System.unique_integer([:positive])}")
    on_exit(fn -> File.rm_rf!(dir) end)
    {:ok, dir: dir}
  end

  test "read/1 returns nil when no stamp exists", %{dir: dir} do
    assert GenerationStamp.read(dir) == nil
  end

  test "write!/1 creates the directory and a stamp that read/1 returns", %{dir: dir} do
    :ok = GenerationStamp.write!(dir)

    stamp = GenerationStamp.read(dir)
    assert is_binary(stamp)
    assert {:ok, _, _} = DateTime.from_iso8601(stamp)
  end

  test "write!/1 replaces an earlier stamp", %{dir: dir} do
    File.mkdir_p!(dir)
    File.write!(Path.join(dir, ".generation_stamp"), "old\n")

    :ok = GenerationStamp.write!(dir)
    assert {:ok, _, _} = DateTime.from_iso8601(GenerationStamp.read(dir))
  end
end
