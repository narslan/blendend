defmodule Blendend.DrawImageTest do
  use ExUnit.Case, async: true
  use Blendend.Draw

  alias Blendend.Canvas
  alias Blendend.Image
  alias Blendend.Style.Color

  defp tmp_path(name) do
    File.mkdir_p!("test/tmp")
    unique = System.unique_integer([:positive])
    "test/tmp/#{name}-#{unique}.png"
  end

  defp write_png!(path) do
    {:ok, canvas} = Canvas.new(2, 3)
    :ok = Canvas.clear(canvas, fill: Color.rgb!(10, 20, 30, 255))
    :ok = File.write(path, Canvas.to_png!(canvas))
    path
  end

  test "image/1 loads images from disk" do
    path = tmp_path("draw-image")
    on_exit(fn -> File.rm(path) end)
    write_png!(path)

    png_image = image(path)

    assert {2, 3} == Image.size!(png_image)
  end

  test "image_a8/2 loads an A8 mask from disk" do
    path = tmp_path("draw-image-a8")
    on_exit(fn -> File.rm(path) end)
    write_png!(path)

    mask = image_a8(path, :luma)

    assert {2, 3} == Image.size!(mask)
  end

  test "blur_image/2 returns an image with the same dimensions" do
    path = tmp_path("draw-image-blur")
    on_exit(fn -> File.rm(path) end)
    write_png!(path)

    png_image = image(path)
    blurred = blur_image(png_image, 4.0)

    assert {2, 3} == Image.size!(blurred)
  end
end
