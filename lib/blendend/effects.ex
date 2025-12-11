defmodule Blendend.Effects do
  @moduledoc """

  This module contains functions to add effects to geometries.

  It currently provides gaussian blur filter and shadow effects on top of it.
  The NIF implementation is based on https://blog.ivank.net/fastest-gaussian-blur.html.

  Gaussian blur is applied after rasterizing a path into an offscreen image,
  then composited back on the destination canvas. So applying a blur to a
  shape is more expensive than most other operations in `blendend`.

  Examples:

      use Blendend.Draw
      clear(fill: rgb(0x42, 0x4D, 0x8C))

      ring =
        path do
          add_circle(220, 210, 96.0)
        end
      
      blur_path(ring, 4,
        mode: :stroke,
        stroke: rgb(90, 200, 255),
        stroke_width: 10.0
      )

  """

  alias Blendend.{Canvas, Error, Native, Path}

  @type blur_mode :: :fill | :stroke | :fill_and_stroke | :both

  @doc """
  Render a blurred copy of `path` onto `canvas`.

  * `sigma` controls blur strength in pixels (roughly `radius = 3 * sigma`).
  * options:
    * `:mode` – `:fill`, `:stroke`, or `:both` (alias `:fill_and_stroke`);
      (defaults to fill if none set)
    * `:offset` – `{dx, dy}` translation before compositing (useful for shadows); values are floats
    * `:resolution` – scale factor `0 < r ≤ 1.0` to render/blur 
       (If blurring feels slow, tune this down. Defaults to 1.0)
  """
  @spec blur_path(Canvas.t(), Path.t(), number(), keyword()) :: :ok | {:error, term()}
  def blur_path(canvas, path, sigma, opts \\ []) do
    Native.canvas_blur_path(canvas, path, sigma * 1.0, opts)
  end

  @doc """
  Same as `blur_path/4`, but raises on failure and returns the canvas.
  """
  @spec blur_path!(Canvas.t(), Path.t(), number(), keyword()) :: Canvas.t()
  def blur_path!(canvas, path, sigma, opts \\ []) do
    case blur_path(canvas, path, sigma, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_blur_path, reason)
    end
  end

  @doc """
  Blur a `path` with an offset to create a soft shadow or glow.

  `dx`/`dy` shift the blurred image; other options are forwarded to `blur_path/4`.
  """
  @spec shadow_path(Canvas.t(), Path.t(), number(), number(), number(), keyword()) ::
          :ok | {:error, term()}
  def shadow_path(canvas, path, dx, dy, sigma, opts \\ []) do
    opts = Keyword.put(opts, :offset, {dx * 1.0, dy * 1.0})
    blur_path(canvas, path, sigma, opts)
  end

  @doc """
  Same as `shadow_path/6`, but raises on failure and returns the canvas.
  """
  @spec shadow_path!(Canvas.t(), Path.t(), number(), number(), number(), keyword()) :: Canvas.t()
  def shadow_path!(canvas, path, dx, dy, sigma, opts \\ []) do
    case shadow_path(canvas, path, dx, dy, sigma, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_blur_path, reason)
    end
  end
end
