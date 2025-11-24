defmodule Blendend.Canvas.Mask do
  @moduledoc """
  Experimental masking helpers for `Blendend.Canvas`.

  ## Examples
      
    alias Blendend.{Canvas, Canvas.Mask, Style.Color, Image}
    mask = Image.from_file!("priv/images/tortoise_mask.png") # with real alpha
    {mw, mh} = Image.size!(mask)
    canvas =
      Canvas.new!(mw, mh)
      |> Canvas.clear!()
      
      :ok =
        Mask.fill(canvas, mask, 0, 0,
          color: Color.rgb!(255, 200, 255),
          alpha: 1.0)
      :ok = Canvas.save!(canvas, "priv/images/masked_canvas.png")
  """

  alias Blendend.{Native, Error}

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
end
