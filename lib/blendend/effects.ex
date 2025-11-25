defmodule Blendend.Effects do
  @moduledoc """
  Shape–driven effects rendered via Blend2D.

  Gaussian blur is applied after rasterizing a path into an offscreen image,
  then composited back on the destination canvas. This lets us build glows,
  soft shadows, or blurred strokes.

  Blur strength is set via `sigma` in pixels. As a rule of thumb, the visible
  radius is about `3 * sigma` (e.g. `sigma: 4.0` yields ~12 px of softness).
  """

  alias Blendend.{Canvas, Error, Native, Path}

  @type blur_mode :: :auto | :fill | :stroke | :fill_and_stroke

  @doc """
  Blur a `path` and composite it back onto `canvas`.

  * `sigma` controls blur strength (in pixels).
  * style options match `Blendend.Canvas.Fill.path/3` (e.g. `fill: color`, `stroke: color`, `stroke_width: w`).
  * extra options:
    * `:mode` – `:auto` (default; follows provided `fill`/`stroke` styles), `:fill`, `:stroke`, or `:fill_and_stroke`
    * `:offset` – `{dx, dy}` shift before compositing (useful for shadows; padding is inferred from blur radius, stroke, and offset)
  """
  @spec blur_path(Canvas.t(), Path.t(), number(), keyword()) :: :ok | {:error, term()}
  def blur_path(canvas, path, sigma, opts \\ []) do
    Native.canvas_blur_path(canvas, path, sigma * 1.0, opts)
  end

  @doc """
  Same as `blur_path/4`, but raises on failure and returns the canvas for piping.
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
    opts = Keyword.put(opts, :offset, {dx, dy})
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
