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

    # White background so we can infer effective alpha from channel attenuation.
    :ok = Canvas.clear(c, fill: Blendend.Style.Color.rgb!(255, 255, 255, 255))
    :ok = Canvas.set_fill_style(c, Blendend.Style.Color.rgb!(255, 0, 0, 255))

    :ok = Canvas.set_global_alpha(c, 0.5)
    :ok = Fill.rect(c, 0, 0, 1, 1)

    :ok = Canvas.set_global_alpha(c, 1.0)
    :ok = Fill.rect(c, 1, 0, 1, 1)

    img = decode_qoi!(c)
    {_r0, g0, _b0, _a0} = pixel!(img, 0, 0)
    {_r1, g1, _b1, _a1} = pixel!(img, 1, 0)

    alpha0 = 1.0 - g0 / 255.0
    alpha1 = 1.0 - g1 / 255.0

    assert alpha0 < alpha1,
           "expected lower effective alpha with global alpha 0.5; got inferred #{alpha0} vs #{alpha1} from pixels #{inspect({g0, g1})}"
  end

  @tag :canvas
  test "set_style_alpha does not leak between fill and stroke" do
    {:ok, c} = Canvas.new(8, 4)

    :ok = Canvas.clear(c, fill: Blendend.Style.Color.rgb!(0, 0, 0, 0))
    :ok = Canvas.set_fill_style(c, Blendend.Style.Color.rgb!(0, 255, 0, 255))
    :ok = Canvas.set_stroke_style(c, Blendend.Style.Color.rgb!(255, 0, 0, 255))

    assert :ok = Canvas.set_style_alpha(c, :stroke, 0.2)
    assert :ok = Canvas.set_style_alpha(c, :fill, 1.0)

    :ok = Stroke.rect(c, 3, 0, 2, 2, stroke_width: 1)
    :ok = Fill.rect(c, 0, 0, 2, 2)

    img = decode_qoi!(c)
    {fr, fg, fb, fa} = pixel!(img, 0, 0)
    {sr, sg, sb, sa} = pixel!(img, 3, 0)

    # Verify stroke stays red-dominant and separate from the green fill, and alpha is reduced.
    assert sr > sg and sr > sb,
           "expected stroke to be red-dominant; got stroke pixel #{inspect({sr, sg, sb, sa})}"

    assert fg > fr and fg > fb,
           "expected fill to be green-dominant; got fill pixel #{inspect({fr, fg, fb, fa})}"

    assert sa < fa,
           "expected stroke alpha < fill alpha; stroke #{inspect(sa)} fill #{inspect(fa)}"
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
