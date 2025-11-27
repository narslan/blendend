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
  test "set_fill_rule and set_comp_op return :ok" do
    {:ok, c} = Canvas.new(10, 10)

    assert :ok = Canvas.set_fill_rule(c, :non_zero)
    assert :ok = Canvas.set_fill_rule(c, :even_odd)

    assert :ok = Canvas.set_comp_op(c, :src_over)
    assert :ok = Canvas.set_comp_op(c, :multiply)
  end

  @tag :canvas
  test "set_global_alpha scales subsequent drawing" do
    {:ok, c} = Canvas.new(4, 2)

    :ok = Canvas.clear(c)
    :ok = Canvas.set_fill_style(c, Blendend.Style.Color.rgb!(255, 255, 255, 255))

    # Half alpha on the first pixel
    :ok = Canvas.set_global_alpha(c, 0.5)
    :ok = Fill.rect(c, 0, 0, 1, 1)

    # Full alpha on a nearby pixel
    :ok = Canvas.set_global_alpha(c, 1.0)
    :ok = Fill.rect(c, 1, 0, 1, 1)

    img = decode_qoi!(c)
    {r0, g0, b0, a0} = pixel!(img, 0, 0)
    {r1, g1, b1, a1} = pixel!(img, 1, 0)

    assert a0 < a1 or r0 < r1 or g0 < g1 or b0 < b1
  end

  @tag :canvas
  test "set_style_alpha targets individual slots" do
    {:ok, c} = Canvas.new(8, 4)

    :ok = Canvas.set_fill_style(c, Blendend.Style.Color.rgb!(255, 255, 255, 255))
    :ok = Canvas.set_style_alpha(c, :fill, 0.25)
    :ok = Fill.rect(c, 0, 0, 1, 1)

    :ok = Canvas.set_style_alpha(c, :fill, 1.0)
    :ok = Fill.rect(c, 1, 0, 1, 1)

    img = decode_qoi!(c)
    {fr0, fg0, fb0, fa0} = pixel!(img, 0, 0)
    {fr1, fg1, fb1, fa1} = pixel!(img, 1, 0)

    assert fa0 <= fa1
    assert fr0 <= fr1 and fg0 <= fg1 and fb0 <= fb1

    :ok = Canvas.clear(c, fill: Blendend.Style.Color.rgb!(0, 0, 0, 0))
    :ok = Canvas.set_stroke_style(c, Blendend.Style.Color.rgb!(255, 0, 0, 255))
    :ok = Canvas.set_style_alpha(c, :stroke, 0.4)
    :ok = Stroke.rect(c, 0, 0, 2, 2, stroke_width: 1.0)

    :ok = Canvas.set_style_alpha(c, :stroke, 1.0)
    :ok = Stroke.rect(c, 4, 0, 2, 2, stroke_width: 1.0)

    img_stroke = decode_qoi!(c)
    {sr0, sg0, sb0, sa0} = pixel!(img_stroke, 0, 0)
    {sr1, _sg1, _sb1, sa1} = pixel!(img_stroke, 4, 0)

    assert sa0 <= sa1
    assert sr0 <= sr1
    assert sr1 > sg0 and sr1 > sb0
  end

  @tag :canvas
  test "disable_style clears fill and stroke independently" do
    {:ok, c} = Canvas.new(8, 8)

    :ok = Canvas.set_fill_style(c, Blendend.Style.Color.rgb!(255, 255, 255, 255))
    :ok = Fill.rect(c, 0, 0, 8, 8)
    :ok = Canvas.disable_style(c, :fill)
    :ok = Fill.rect(c, 0, 0, 8, 8)

    img = decode_qoi!(c)
    px_fill = pixel!(img, 0, 0)
    assert px_fill == {255, 255, 255, 255}

    :ok = Canvas.set_stroke_style(c, Blendend.Style.Color.rgb!(0, 0, 0, 255))
    :ok = Stroke.rect(c, 0, 0, 8, 8, stroke_width: 1.0)
    img_after_stroke = decode_qoi!(c)
    px_stroke = pixel!(img_after_stroke, 0, 0)
    :ok = Canvas.disable_style(c, :stroke)
    :ok = Stroke.rect(c, 0, 0, 8, 8, stroke_width: 1.0)

    img2 = decode_qoi!(c)
    assert pixel!(img2, 0, 0) == px_stroke
  end
end
