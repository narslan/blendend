defmodule Blendend.CanvasSizeTest do
  use ExUnit.Case, async: true

  alias Blendend.Canvas

  @tag :canvas
  test "size/1 returns canvas dimensions without encoding" do
    {:ok, canvas} = Canvas.new(123, 45)

    assert {:ok, {123, 45}} = Canvas.size(canvas)
    assert {123, 45} = Canvas.size!(canvas)
  end

  @tag :canvas
  test "Draw.canvas_size/0 returns current canvas dimensions" do
    use Blendend.Draw

    {:ok, _} =
      draw 77, 88 do
        assert {77, 88} = canvas_size()
      end
  end
end
