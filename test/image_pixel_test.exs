defmodule Blendend.ImagePixelTest do
  use ExUnit.Case, async: true

  alias Blendend.Canvas
  alias Blendend.Image
  alias Blendend.Style.Color

  test "pixel_at!/3 reads RGBA from a decoded PNG image" do
    {:ok, canvas} = Canvas.new(2, 2)
    :ok = Canvas.clear(canvas)

    :ok = Canvas.Fill.rect(canvas, 0, 0, 1, 1, fill: Color.rgb!(255, 0, 0, 128))
    :ok = Canvas.Fill.rect(canvas, 1, 1, 1, 1, fill: Color.rgb!(0, 255, 0, 255))

    {:ok, image} = Image.from_data(Canvas.to_png!(canvas))

    assert Image.pixel_at!(image, 0, 0) == {255, 0, 0, 128}
    assert Image.pixel_at!(image, 1, 1) == {0, 255, 0, 255}
    assert Image.pixel_at!(image, 0, 1) == {0, 0, 0, 0}
  end
end
