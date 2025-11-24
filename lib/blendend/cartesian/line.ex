defmodule Blendend.Cartesian.Line do
  @moduledoc """
  Line plotting helpers on top of `Blendend.Cartesian`.

  It maps **math-space** points `{x, y}` into canvas pixels via
  `Blendend.Cartesian.to_canvas!/3` and strokes a polyline.
  """

  alias Blendend.Canvas
  alias Blendend.Cartesian
  alias Blendend.Style.Color

  @type plot_style :: [
          stroke: any(),
          stroke_width: number()
        ]

  @doc """
  Draws a polyline for a function `y = f(x)` on an existing frame.

  Arguments:

    * `canvas`      – a `Blendend.Canvas.t()`
    * `frame`       – a `Blendend.Cartesian.t()`
    * `math_points` – list of `{x, y}` in **math space**
    * `opts`        – `:stroke_color`, `:stroke_width`

  This function:

    1. uses `Cartesian.to_canvas!/3` to map each `{x, y}` to `{px, py}`
    2. calls `Canvas.Stroke.polyline/3` with those points

  """
  @spec plot_function(Canvas.t(), Cartesian.t(), [{number(), number()}], plot_style) :: :ok
  def plot_function(canvas, frame, math_points, opts \\ []) do
    stroke_color = Keyword.get(opts, :stroke, Color.rgb!(0, 155, 255))
    stroke_width = Keyword.get(opts, :stroke_width, 2.0)

    canvas_points =
      for {x, y} <- math_points do
        Cartesian.to_canvas!(frame, x, y)
      end

    Canvas.Stroke.polyline(canvas, canvas_points,
      stroke: stroke_color,
      stroke_width: stroke_width
    )

    :ok
  end

  @doc """
  Draws a polyline for a parametric curve on an existing frame.

  Arguments:

    * `canvas`      – a `Blendend.Canvas.t()`
    * `frame`       – a `Blendend.Cartesian.t()`
    * `math_points` – list of `{x, y}` in **math space**
    * `opts`        – `:stroke_color`, `:stroke_width`

  This is the parametric analogue of `plot_function/4`. It assumes you already
  sampled your parametric curve into `{x, y}` points using
  `Blendend.Cartesian.sample_parametric/4` or `Blendend.Cartesian.frame_from_parametric/6`.

    Example with a Lissajous curve:

      lissajous = fn t -> { :math.sin(3 * t), :math.sin(4 * t) } end

      {:ok, frame, pts} =
        Blendend.Cartesian.frame_from_parametric(
          lissajous, 0.0, 2.0 * :math.pi(), 400, 400, 800
        )

      c = Blendend.Draw.get_canvas()

      Blendend.Cartesian.Line.plot_curve(c, frame, pts,
        stroke: Color.rgb!(255, 100, 0),
        stroke_width: 2.0)

  """
  @spec plot_curve(Canvas.t(), Cartesian.t(), [{number(), number()}], plot_style) :: :ok
  def plot_curve(canvas, frame, math_points, opts \\ []) do
    stroke_color = Keyword.get(opts, :stroke, Color.rgb!(0, 155, 255))
    stroke_width = Keyword.get(opts, :stroke_width, 2.0)

    canvas_points =
      for {x, y} <- math_points do
        Cartesian.to_canvas!(frame, x, y)
      end

    Canvas.Stroke.polyline(canvas, canvas_points,
      stroke: stroke_color,
      stroke_width: stroke_width
    )

    :ok
  end

  @deprecated "Use plot_function/4 for y=f(x) plots."
  def plot_y(canvas, frame, math_points, opts \\ []) do
    plot_function(canvas, frame, math_points, opts)
  end

  @deprecated "Use plot_curve/4 for parametric plots."
  def plot_parametric(canvas, frame, math_points, opts \\ []) do
    plot_curve(canvas, frame, math_points, opts)
  end
end
