defmodule Blendend.Canvas.Clip do
  @moduledoc """
  Rectangular clipping for `Blendend.Canvas`.

  All functions modify the canvas' current clip region. The clip is part of the
  drawing state and can be saved/restored with
  `Blendend.Canvas.save_state/1` and `Blendend.Canvas.restore_state/1`.

  ## Example

      use Blendend.Draw
      alias Blendend.{Canvas, Canvas.Clip, Style.Color}

      draw 240, 160, "clipped.png" do
        canvas = Blendend.Draw.get_canvas()

        Canvas.save_state!(canvas)
        Clip.to_rect!(canvas, 40, 30, 160, 100)

        clear color: rgb(235, 235, 235)
        rect 0, 0, 240, 160, fill: rgb(255, 120, 120)

        Canvas.restore_state!(canvas)
        rect 30, 20, 180, 120, stroke: Color.rgb!(40, 40, 40)
      end

  The red fill is clipped to the 160×100 window, while the stroked outline is
  drawn after restoring the clip.
  """

  alias Blendend.{Native, Error}

  @type canvas :: Blendend.Canvas.t()

  @doc """
  Intersects the current clip with the rectangle `{x, y, w, h}`.

  Coordinates are given in user space.

  On success returns `:ok`. On failure, returns `{:error, reason}`.
  """
  @spec to_rect(canvas, number(), number(), number(), number()) ::
          :ok | {:error, term()}
  def to_rect(canvas, x, y, w, h),
    do: Native.canvas_clip_to_rect(canvas, x * 1.0, y * 1.0, w * 1.0, h * 1.0)

  @doc """
  Same as `to_rect/5`, but raises `Blendend.Error` on failure and returns
  the `canvas` for use in pipelines.
  """
  @spec to_rect!(canvas, number(), number(), number(), number()) :: canvas
  def to_rect!(canvas, x, y, w, h) do
    case to_rect(canvas, x, y, w, h) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_clip_to_rect, reason)
    end
  end
end
