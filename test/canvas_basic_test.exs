defmodule Blendend.CanvasBasicTest do
  use ExUnit.Case, async: true

  alias Blendend.Canvas
  alias Blendend.Canvas.{Fill, Stroke}
  alias Blendend.Test.ImageHelpers

  defp decode_qoi!(canvas) do
    canvas
    |> Canvas.to_qoi!()
    |> ImageHelpers.decode_qoi!()
  end

  defp pixel!(img, x, y), do: ImageHelpers.pixel_at(img, x, y)

  @tag :canvas
  test "new/2 returns a usable canvas" do
    assert {:ok, c} = Canvas.new(64, 64)
    assert %{width: 64, height: 64} = decode_qoi!(c)
  end

  @tag :canvas
  test "clear/2 fills background with a solid color" do
    {:ok, c} = Canvas.new(8, 8)

    :ok = Canvas.clear(c, fill: Blendend.Style.Color.rgb!(0, 0, 0, 255))
    img0 = decode_qoi!(c)
    px0 = ImageHelpers.pixel_at(img0, 0, 0)

    :ok = Canvas.clear(c, fill: Blendend.Style.Color.rgb!(255, 255, 255, 255))
    img1 = decode_qoi!(c)

    assert pixel!(img1, 0, 0) == {255, 255, 255, 255}
    refute px0 == {255, 255, 255, 255}
  end

  @tag :canvas
  test "fill_rect paints the expected region" do
    {:ok, c} = Canvas.new(32, 32)

    :ok = Canvas.clear(c, fill: Blendend.Style.Color.rgb!(255, 255, 255, 255))

    :ok =
      Fill.rect(c, 4, 4, 24, 24, fill: Blendend.Style.Color.rgb!(0, 0, 0, 255))

    img = decode_qoi!(c)
    assert pixel!(img, 5, 5) == {0, 0, 0, 255}
    assert pixel!(img, 0, 0) == {255, 255, 255, 255}
  end

  @tag :canvas
  test "stroke_line draws on the expected pixels" do
    {:ok, c} = Canvas.new(32, 32)

    :ok = Canvas.clear(c, fill: Blendend.Style.Color.rgb!(255, 255, 255, 255))

    :ok =
      Stroke.line(c, 2, 2, 30, 30,
        stroke_fill: Blendend.Style.Color.rgb!(0, 0, 0, 255),
        stroke_width: 2.0
      )

    img = decode_qoi!(c)

    assert pixel!(img, 2, 2) != {255, 255, 255, 255}
    assert pixel!(img, 0, 31) == {255, 255, 255, 255}
  end

  @tag :canvas
  test "set_fill_rule returns :ok for supported rules" do
    {:ok, c} = Canvas.new(10, 10)

    assert :ok = Canvas.set_fill_rule(c, :non_zero)
    assert :ok = Canvas.set_fill_rule(c, :even_odd)
  end
end
