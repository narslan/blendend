defmodule Blendend.RenderTest do
  use ExUnit.Case, async: true
  alias Blendend.Canvas
  alias Blendend.Test.ImageHelpers

  @tag :slow
  test "translate moves the rectangle" do
    {:ok, ctx} = Canvas.new(64, 64)
    :ok = Canvas.clear(ctx)

    :ok =
      Blendend.Canvas.Fill.rect(
        ctx,
        10,
        10,
        20,
        20,
        fill: Blendend.Style.Color.rgb!(255, 0, 0)
      )

    img1 =
      ctx
      |> Canvas.to_qoi!()
      |> ImageHelpers.decode_qoi!()

    :ok = Canvas.clear(ctx)
    :ok = Canvas.translate(ctx, 30, 0)

    :ok =
      Blendend.Canvas.Fill.rect(
        ctx,
        10,
        10,
        20,
        20,
        fill: Blendend.Style.Color.rgb!(255, 0, 0)
      )

    img2 =
      ctx
      |> Canvas.to_qoi!()
      |> ImageHelpers.decode_qoi!()

    assert ImageHelpers.pixel_at(img1, 12, 12) == {255, 0, 0, 255}
    assert ImageHelpers.pixel_at(img2, 0, 0) == {0, 0, 0, 0}
    assert ImageHelpers.pixel_at(img2, 45, 12) == {255, 0, 0, 255}
  end
end
