defmodule Blendend.CanvasBlitTest do
  use ExUnit.Case, async: true

  alias Blendend.Canvas
  alias Blendend.Image
  alias Blendend.Style.Color
  alias Blendend.Test.ImageHelpers

  defp decode_qoi!(canvas) do
    canvas
    |> Canvas.to_qoi!()
    |> ImageHelpers.decode_qoi!()
  end

  defp pixel!(img, x, y), do: ImageHelpers.pixel_at(img, x, y)

  defp solid_image!(width, height, color) do
    {:ok, canvas} = Canvas.new(width, height)
    :ok = Canvas.clear(canvas, fill: color)
    {:ok, image} = Image.from_data(Canvas.to_png!(canvas))
    image
  end

  @tag :canvas
  test "blit_image/4 copies source pixels at the target position" do
    {:ok, canvas} = Canvas.new(4, 4)
    :ok = Canvas.clear(canvas, fill: Color.rgb!(255, 255, 255, 255))

    image = solid_image!(2, 2, Color.rgb!(255, 0, 0, 255))

    assert :ok = Canvas.blit_image(canvas, image, 1, 1)

    img = decode_qoi!(canvas)
    assert pixel!(img, 1, 1) == {255, 0, 0, 255}
    assert pixel!(img, 0, 0) == {255, 255, 255, 255}
  end

  @tag :canvas
  test "blit_image/6 scales source to the destination rectangle" do
    {:ok, canvas} = Canvas.new(4, 4)
    :ok = Canvas.clear(canvas, fill: Color.rgb!(255, 255, 255, 255))

    image = solid_image!(1, 1, Color.rgb!(0, 0, 255, 255))

    assert :ok = Canvas.blit_image(canvas, image, 1, 1, 2, 2)

    img = decode_qoi!(canvas)
    assert pixel!(img, 2, 2) == {0, 0, 255, 255}
    assert pixel!(img, 0, 0) == {255, 255, 255, 255}
  end
end
