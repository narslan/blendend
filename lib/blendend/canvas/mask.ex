defmodule Blendend.Canvas.Mask do
  @moduledoc """
  Experimental masking helpers for `Blendend.Canvas`.

  ## Examples
  ```    
  alias Blendend.{Canvas, Canvas.Mask, Style.Color, Image}
  mask = Image.from_file_a8!("priv/images/splash.png", :red)
  {mw, mh} = Image.size!(mask)

  canvas =
  Canvas.new!(mw, mh)
  |> Canvas.clear!()

  :ok =
  Mask.fill(canvas, mask, 0, 0,
    color: Color.rgb!(255, 200, 255),
    alpha: 1.0
  )

  :ok = Canvas.save!(canvas, "priv/images/masked_canvas.png")
  ```
  To blur a mask (e.g. soft shadows), use `blur_fill/6` and set `sigma` in pixels.
  A `sigma` of 3.0 produces a visible blur radius around ~9 px.
  """

  alias Blendend.{Native, Error}
  alias Blendend.Image

  @type canvas :: Blendend.Canvas.t()
  @type image :: Blendend.Image.t()

  @doc """
  Fills using the current style through an image **mask** anchored at `{x, y}`.
  `x` and `y` are numbers.

  On success returns `:ok`. On failure returns `{:error, reason}`.

  """
  @spec fill(canvas, image, number(), number(), keyword()) ::
          :ok | {:error, term()}
  def fill(canvas, img, x, y, opts \\ []) do
    case opts do
      [] -> Native.canvas_fill_mask(canvas, img, x * 1.0, y * 1.0)
      _ -> Native.canvas_fill_mask(canvas, img, x * 1.0, y * 1.0, opts)
    end
  end

  @doc """
  Same as `fill/5`, but raises `Blendend.Error` on failure and returns
  the `canvas` for use in pipelines.
  """
  @spec fill!(canvas, image, number(), number(), keyword()) :: canvas
  def fill!(canvas, img, x, y, opts \\ []) do
    case fill(canvas, img, x, y, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_fill_mask, reason)
    end
  end

  @doc """
  Blurs a mask image with `sigma` and fills it at `{x, y}`.

  Returns `:ok` on success or `{:error, reason}`. Uses the same options as `fill/5`.
  """
  @spec blur_fill(canvas, image, number(), number(), number(), keyword()) ::
          :ok | {:error, term()}
  def blur_fill(canvas, img, x, y, sigma, opts \\ []) do
    with {:ok, blurred} <- Image.blur(img, sigma) do
      fill(canvas, blurred, x, y, opts)
    end
  end

  @doc """
  Same as `blur_fill/6`, but raises and returns the canvas on success.
  """
  @spec blur_fill!(canvas, image, number(), number(), number(), keyword()) :: canvas
  def blur_fill!(canvas, img, x, y, sigma, opts \\ []) do
    case blur_fill(canvas, img, x, y, sigma, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_blur_mask, reason)
    end
  end
end
