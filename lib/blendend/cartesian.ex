defmodule Blendend.Cartesian do
  @moduledoc """
  A helper layer for plotting and coordinate transforms on top of Blendend.

  A `Blendend.Cartesian` value is an opaque handle (a NIF resource) that
  represents a 2D Cartesian coordinate system mapped onto a canvas.

  It describes:

    * a **cartesian-space domain**:
      * `x_min .. x_max`
      * `y_min .. y_max`
    * a **canvas region** in pixels:
      * `width x height`

  and provides functions to:

    * convert points between **math space** and **pixel space**
    * **sample** functions (`sample_function/4` for y = f(x)) and
      **sample** parametric curves (`sample_parametric/4` for {x(t), y(t)})
    * build a frame that automatically **fits** a set of points

  Examples (function plot):
      alias Blendend.{Canvas, Style, Cartesian}
      alias Blendend.Cartesian.Line

      {:ok, frame} = Cartesian.new(-:math.pi(), :math.pi(), -1.0, 1.0, 400, 300)
      points = Cartesian.sample_function(&:math.sin/1, -:math.pi(), :math.pi(), 400)
      c = Canvas.new!(400, 300)
      Line.plot_function(c, frame, points, stroke: Style.color(0, 155, 255))

  Examples (let the frame auto-fit your points):
      {:ok, frame, points} =
        Cartesian.frame_from_y(&:math.sin/1, -:math.pi(), :math.pi(), 400, 300, 400,
          padding: 0.08, preserve_aspect: true)

      Line.plot_function(c, frame, points, stroke: Style.color(0, 155, 255), stroke_width: 2.0)

  Examples (parametric curve):
      curve = fn t ->
        x = :math.cos(t)
        y = :math.sin(2 * t)
        {x, y}
      end

      {:ok, frame, pts} =
        Cartesian.frame_from_parametric(curve, 0.0, 2.0 * :math.pi(), 400, 400, 800, padding: 0.05)

      Line.plot_curve(c, frame, pts, stroke: Style.color(255, 100, 0), stroke_width: 2.0)

  """

  @opaque t :: reference()

  @type plot_style :: [
          stroke_color: any(),
          stroke_width: number()
        ]

  @type frame_opts :: [
          padding: float(),
          preserve_aspect: boolean()
        ]

  alias Blendend.Error

  ## ------------------------------------------------------------------------
  ## Core construction & transforms
  ## ------------------------------------------------------------------------

  @doc """
  Creates a new Cartesian system with the given bounds and dimensions.

  Arguments:

    * `x_min`, `x_max` – math-space X range
    * `y_min`, `y_max` – math-space Y range
    * `width`, `height` – canvas size in pixels

  Example:

      iex> {:ok, cart} = Blendend.Cartesian.new(-:math.pi(), :math.pi(), -1.0, 1.0, 400, 300)

  On success, returns `{:ok, cart}` (an opaque resource).

  On failure, returns `{:error, reason}`.
  """
  @spec new(number, number, number, number, pos_integer, pos_integer) ::
          {:ok, t} | {:error, term()}
  defdelegate new(x_min, x_max, y_min, y_max, width, height),
    to: Blendend.Native,
    as: :cartesian

  @doc """
  Same as `new/6`, but returns the Cartesian system directly and raises on failure.

  Useful in setups where we expect construction to always succeed:

      cart = Blendend.Cartesian.new!(-1.0, 1.0, -1.0, 1.0, 512, 512)
  """
  @spec new!(number, number, number, number, pos_integer, pos_integer) :: t
  def new!(x_min, x_max, y_min, y_max, w, h) do
    case new(x_min, x_max, y_min, y_max, w, h) do
      {:ok, cart} -> cart
      {:error, reason} -> raise Error.new(:cartesian_new, reason)
    end
  end

  @doc """
  Converts a point from **math coordinates** `(x, y)` to **canvas pixels** `{px, py}`.

  Notes:

    * the Y axis is flipped compared to math space:
      positive Y goes *up* in math, but *down* in pixel space
    * the exact mapping depends on the bounds you used in `new/6` or `from_points/4`

  On success, returns `{:ok, {px, py}}`.

  On failure, returns `{:error, reason}`.
  """
  @spec to_canvas(t(), number(), number()) ::
          {:ok, {number(), number()}} | {:error, term()}
  defdelegate to_canvas(cart, x, y),
    to: Blendend.Native,
    as: :cartesian_to_canvas

  @doc """
  Same as `to_canvas/3`, but returns `{px, py}` and raises on error.

  Example:

      {px, py} = Blendend.Cartesian.to_canvas!(cart, 0.0, 1.0)
  """
  @spec to_canvas!(t(), number(), number()) :: {number(), number()}
  def to_canvas!(cart, x, y) do
    case to_canvas(cart, x, y) do
      {:ok, point} -> point
      {:error, reason} -> raise Error.new(:cartesian_to_canvas, reason)
    end
  end

  @doc """
  Converts a point from **canvas pixels** `(px, py)` back to **math (Cartesian) coordinates** `{x, y}`.

  This is useful when you get a pixel position and want
  to know which coordinate that corresponds to.

  On success, returns `{:ok, {x, y}}`.

  On failure, returns `{:error, reason}`.
  """
  @spec to_math(t(), number(), number()) ::
          {:ok, {number(), number()}} | {:error, term()}
  defdelegate to_math(cart, px, py),
    to: Blendend.Native,
    as: :cartesian_to_math

  @doc """
  Same as `to_math/3`, but returns `{x, y}` directly or raises on error.

      {x, y} = Blendend.Cartesian.to_math!(cart, px, py)
  """
  @spec to_math!(t(), number(), number()) :: {number(), number()}
  def to_math!(cart, px, py) do
    case to_math(cart, px, py) do
      {:ok, point} -> point
      {:error, reason} -> raise Error.new(:cartesian_to_math, reason)
    end
  end

  @doc """
  Samples a parametric curve `{x(t), y(t)}` over the interval `t0..t1`.

    * `fun` takes `t` and returns `{x, y}` in math space
    * `steps` controls how many segments you get; result length is `steps + 1`

  Returns the sampled `{x, y}` list in math space; combine with
  `plot_curve/4` (or `Blendend.Draw.plot_curve/3`) to draw it.
  """
  @spec sample_parametric((number() -> point), number(), number(), non_neg_integer()) ::
          [point]
        when point: term()
  def sample_parametric(fun, t0, t1, steps) do
    for i <- 0..steps do
      t = t0 + (t1 - t0) * i / steps
      fun.(t)
    end
  end

  @doc """
  Samples an ordinary function `y = f(x)` over a given x-range.

  Equivalent to:

      sample_parametric(fn x -> {x, fun.(x)} end, x_min, x_max, steps)

  and returns a list of `{x, y}` tuples in **math space**.
  """
  @spec sample_function((number() -> number()), number(), number(), non_neg_integer()) ::
          [{number(), number()}]
  def sample_function(fun, x_min, x_max, steps),
    do: sample_parametric(fn x -> {x, fun.(x)} end, x_min, x_max, steps)

  @doc false
  defp bbox(points) do
    {xs, ys} = Enum.unzip(points)
    {Enum.min(xs), Enum.max(xs), Enum.min(ys), Enum.max(ys)}
  end

  @doc false
  defp expand_bounds({xmin, xmax, ymin, ymax}, pad_frac, canvas_w, canvas_h, preserve_aspect?) do
    dx = xmax - xmin
    dy = ymax - ymin
    px = max(dx * pad_frac, 1.0e-9)
    py = max(dy * pad_frac, 1.0e-9)
    {xmin0, xmax0, ymin0, ymax0} = {xmin - px, xmax + px, ymin - py, ymax + py}

    if preserve_aspect? do
      target = canvas_w / canvas_h
      cur = (xmax0 - xmin0) / (ymax0 - ymin0)

      cond do
        # widen X to match the canvas aspect
        cur < target ->
          cx = (xmin0 + xmax0) / 2
          new_dx = target * (ymax0 - ymin0)
          {cx - new_dx / 2, cx + new_dx / 2, ymin0, ymax0}

        # extend Y to match the canvas aspect
        cur > target ->
          cy = (ymin0 + ymax0) / 2
          new_dy = (xmax0 - xmin0) / target
          {xmin0, xmax0, cy - new_dy / 2, cy + new_dy / 2}

        true ->
          {xmin0, xmax0, ymin0, ymax0}
      end
    else
      {xmin0, xmax0, ymin0, ymax0}
    end
  end

  @doc """
  Constructs a Cartesian coordinate system that tightly frames a set of points.

  Given:

    * `points` – a list of `{x, y}` tuples in **math space**
    * `w`, `h` – target canvas width and height in pixels
    * `opts`   – fitting options

  this function:

    1. computes the bounding box of `points`
    2. expands it by a padding fraction
    3. optionally adjusts it to match the canvas aspect ratio
    4. creates a `Blendend.Cartesian` using those bounds and the
       given `w`/`h`

  Recognised options:

    * `:padding` – extra margin around the data as a fraction of the
      data size (default: `0.08` - 8% on each side)
    * `:preserve_aspect` – if `true` (default), the fitted bounds are
      adjusted so that the math aspect ratio matches `w / h` exactly,
      avoiding distortion when mapping to pixels.
      This is particularly useful for parametric curves or scattered
      points where we don't want to hand-pick `x_min` / `x_max` /
      `y_min` / `y_max`.

  On success, returns `{:ok, cart}`.

  On failure, returns `{:error, reason}` from `new/6`.
  """

  @spec from_points([{number(), number()}], pos_integer(), pos_integer(), keyword()) ::
          {:ok, t()} | {:error, term()}
  def from_points(points, w, h, opts \\ []) do
    pad = Keyword.get(opts, :padding, 0.08)
    keep_aspect = Keyword.get(opts, :preserve_aspect, true)

    {xmin, xmax, ymin, ymax} =
      points
      |> bbox()
      |> expand_bounds(pad, w, h, keep_aspect)

    new(xmin, xmax, ymin, ymax, w, h)
  end
end
