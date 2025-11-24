defmodule Blendend.PathTest do
  use ExUnit.Case, async: true
  alias Blendend.Path

  test "vertex count and closed path" do
    p =
      Path.new!()
      |> Path.move_to!(10, 10)
      |> Path.line_to!(60, 10)
      |> Path.line_to!(60, 40)
      |> Path.line_to!(10, 40)
      |> Path.close!()

    # 4 lines + close
    assert Path.vertex_count!(p) == 5
    assert Path.hit_test(p, 20, 20) == :in
    assert Path.hit_test(p, 5, 5) == :out
  end

  test "add_path merges vertices" do
    a =
      Path.new!()
      |> Path.add_circle!(30, 30, 10)

    b =
      Path.new!()
      |> Path.move_to!(10, 10)
      |> Path.line_to!(15, 10)
      |> Path.close!()

    count = Path.vertex_count!(a)
    a2 = Path.add_path!(a, b)
    assert Path.vertex_count!(a2) == count + Path.vertex_count!(b)
  end
end
