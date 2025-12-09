defmodule Blendend.Canvas.Stroke do
  @moduledoc """
  Stroke functions for `Blendend.Canvas` to stroke a 
  geometry on the canvas with a style (color, gradient or pattern).

  Prefer the `Blendend.Draw` macros; they call into this
  module under the hood.

      use Blendend.Draw

      draw 240, 160, "stroke_example.png" do
        clear fill: rgb(250, 250, 250)

        line 20, 20, 220, 140, stroke: rgb(30, 30, 30), stroke_width: 4
        circle 120, 80, 40, stroke: rgb(200, 60, 60), stroke_width: 3
      end
  """

  alias Blendend.{Native, Error}

  @type canvas :: Blendend.Canvas.t()
  @type opts :: keyword()

  # ===========================================================================
  # Path
  # ===========================================================================

  @doc """
  Strokes `path` on `canvas` using the given stroke options.

  `path` must be a `Blendend.Path.t()`.

  ## Stroke options

  The `opts` keyword list controls the stroke appearance. Common keys:

    * `:stroke`
      - stroke brush (solid color), from `Blendend.Style.Color.*`
      – gradient stroke brush, from `Blendend.Style.Gradient.*`
      – pattern stroke brush, from `Blendend.Style.Pattern.create/1`
      (default is black color)
    * `:stroke_width` – stroke width as a float (default: 1.0)
    * `:stroke_cap` – cap style at line ends:

        * `:butt` (default)
        * `:square`
        * `:round`
        * `:round_rev`
        * `:triangle`
        * `:triangle_rev`

    * `:stroke_line_join` – join style between segments:

        * `:miter_clip`
        * `:miter_bevel`
        * `:miter_round`
        * `:bevel`
        * `:round`
    * `:stroke_miter_limit` – miter limit as float (only for `:miter` joins)
    * `:comp_op` – compositing operator atom. See `Blendend.Canvas.Fill.path/3`
    * `:stroke_alpha` - extra opacity multiplier (values are `0.0..1.0`)
  If you omit brush options, default values are set.

  ## Examples

      alias Blendend.{Canvas, Path, Style}
      alias Blendend.Canvas.Stroke

      canvas = Canvas.new!(200, 200)

      path =
        Path.new!()
        |> Path.move_to!(20, 20)
        |> Path.line_to!(180, 180)

      :ok =
        Stroke.path(canvas, path,
          stroke_color: Style.color(0, 0, 0),
          stroke_width: 2.0,
          stroke_cap: :round
        )

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec path(canvas(), Blendend.Path.t(), opts()) :: :ok | {:error, term()}
  def path(canvas, path, opts \\ []),
    do: Native.canvas_stroke_path(canvas, path, opts)

  @doc """
  Same as `path/3`, but returns the canvas and raises on error.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec path!(canvas(), Blendend.Path.t(), opts()) :: canvas()
  def path!(canvas, path, opts \\ []) do
    case path(canvas, path, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_stroke_path, reason)
    end
  end

  # ===========================================================================
  # Shapes
  # ===========================================================================

  @doc """
  Strokes a line from `(x0, y0)` to `(x1, y1)`.

  Uses the same stroke options as `path/3`.
  """
  @spec line(canvas(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def line(canvas, x0, y0, x1, y1, opts \\ []) do
    Native.canvas_stroke_line(canvas, x0 * 1.0, y0 * 1.0, x1 * 1.0, y1 * 1.0, opts)
  end

  @doc """
  Same as `line/6`, but returns the canvas and raises on error.
  """
  @spec line!(canvas(), number(), number(), number(), number(), opts()) :: canvas()
  def line!(canvas, x0, y0, x1, y1, opts \\ []) do
    case line(canvas, x0, y0, x1, y1, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_line, reason)
    end
  end

  @doc """
  Strokes a rectangle `(x, y, w, h)`.

  Uses the same stroke options as `path/3`.
  """
  @spec rect(canvas(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def rect(canvas, x, y, w, h, opts \\ []) do
    Native.canvas_stroke_rect(canvas, x * 1.0, y * 1.0, w * 1.0, h * 1.0, opts)
  end

  @doc """
  Same as `rect/6`, but returns the canvas and raises on error.
  """
  @spec rect!(canvas(), number(), number(), number(), number(), opts()) :: canvas()
  def rect!(canvas, x, y, w, h, opts \\ []) do
    case rect(canvas, x, y, w, h, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_rect, reason)
    end
  end

  @doc """
  Strokes a box `{x0, y0, x1, y1}`.

  Uses the same stroke options as `path/3`.
  """
  @spec box(canvas(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def box(canvas, x0, y0, x1, y1, opts \\ []) do
    Native.canvas_stroke_box(canvas, x0 * 1.0, y0 * 1.0, x1 * 1.0, y1 * 1.0, opts)
  end

  @doc """
  Same as `box/6`, but returns the canvas and raises on error.
  """
  @spec box!(canvas(), number(), number(), number(), number(), opts()) :: canvas()
  def box!(canvas, x0, y0, x1, y1, opts \\ []) do
    case box(canvas, x0, y0, x1, y1, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_box, reason)
    end
  end

  @doc """
  Strokes a circle at `(cx, cy)` with radius `r`.

  Uses the same stroke options as `path/3`.
  """
  @spec circle(canvas(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def circle(canvas, cx, cy, r, opts \\ []) do
    Native.canvas_stroke_circle(canvas, cx * 1.0, cy * 1.0, r * 1.0, opts)
  end

  @doc """
  Same as `circle/5`, but returns the canvas and raises on error.
  """
  @spec circle!(canvas(), number(), number(), number(), opts()) :: canvas()
  def circle!(canvas, cx, cy, r, opts \\ []) do
    case circle(canvas, cx, cy, r, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_circle, reason)
    end
  end

  @doc """
  Strokes an ellipse at `(cx, cy)` with radii `rx` and `ry`.

  Uses the same stroke options as `path/3`.
  """
  @spec ellipse(canvas(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def ellipse(canvas, cx, cy, rx, ry, opts \\ []) do
    Native.canvas_stroke_ellipse(canvas, cx * 1.0, cy * 1.0, rx * 1.0, ry * 1.0, opts)
  end

  @doc """
  Same as `ellipse/6`, but returns the canvas and raises on error.
  """
  @spec ellipse!(canvas(), number(), number(), number(), number(), opts()) :: canvas()
  def ellipse!(canvas, cx, cy, rx, ry, opts \\ []) do
    case ellipse(canvas, cx, cy, rx, ry, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_ellipse, reason)
    end
  end

  @doc """
  Strokes a rounded rectangle `(x, y, w, h)` with corner radii `(rx, ry)`.

  Uses the same stroke options as `path/3`.
  """
  @spec round_rect(canvas(), number(), number(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def round_rect(canvas, x, y, w, h, rx, ry, opts \\ []) do
    Native.canvas_stroke_round_rect(
      canvas,
      x * 1.0,
      y * 1.0,
      w * 1.0,
      h * 1.0,
      rx * 1.0,
      ry * 1.0,
      opts
    )
  end

  @doc """
  Same as `round_rect/8`, but returns the canvas and raises on error.
  """
  @spec round_rect!(
          canvas(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          opts()
        ) :: canvas()
  def round_rect!(canvas, x, y, w, h, rx, ry, opts \\ []) do
    case round_rect(canvas, x, y, w, h, rx, ry, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_round_rect, reason)
    end
  end

  @doc """
  Strokes an elliptical arc.

  Parameters describe an ellipse centered at `(cx, cy)` with radii `rx`, `ry`
  and angles `start_angle` / `sweep_angle` in radians.

  Uses the same stroke options as `path/3`.
  """
  @spec arc(
          canvas(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          opts()
        ) :: :ok | {:error, term()}
  def arc(canvas, cx, cy, rx, ry, start_angle, sweep_angle, opts \\ []) do
    Native.canvas_stroke_arc(
      canvas,
      cx * 1.0,
      cy * 1.0,
      rx * 1.0,
      ry * 1.0,
      start_angle * 1.0,
      sweep_angle * 1.0,
      opts
    )
  end

  @doc """
  Same as `arc/8`, but returns the canvas and raises on error.
  """
  @spec arc!(
          canvas(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          opts()
        ) :: canvas()
  def arc!(canvas, cx, cy, rx, ry, start_angle, sweep_angle, opts \\ []) do
    case arc(canvas, cx, cy, rx, ry, start_angle, sweep_angle, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_arc, reason)
    end
  end

  @doc """
  Strokes a chord/segment of an ellipse (arc + straight line between endpoints).

  Uses the same stroke options as `path/3`.
  """
  @spec chord(
          canvas(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          opts()
        ) :: :ok | {:error, term()}
  def chord(canvas, cx, cy, rx, ry, start_angle, sweep_angle, opts \\ []) do
    Native.canvas_stroke_chord(
      canvas,
      cx * 1.0,
      cy * 1.0,
      rx * 1.0,
      ry * 1.0,
      start_angle * 1.0,
      sweep_angle * 1.0,
      opts
    )
  end

  @doc """
  Same as `chord/8`, but returns the canvas and raises on error.
  """
  @spec chord!(
          canvas(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          opts()
        ) :: canvas()
  def chord!(canvas, cx, cy, rx, ry, start_angle, sweep_angle, opts \\ []) do
    case chord(canvas, cx, cy, rx, ry, start_angle, sweep_angle, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_chord, reason)
    end
  end

  @doc """
  Strokes a pie/sector shape.

  Same parameters as `chord/8`, but the arc is also connected back to the
  ellipse center.

  Uses the same stroke options as `path/3`.
  """
  @spec pie(
          canvas(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          opts()
        ) :: :ok | {:error, term()}
  def pie(canvas, cx, cy, rx, ry, start_angle, sweep_angle, opts \\ []) do
    Native.canvas_stroke_pie(
      canvas,
      cx * 1.0,
      cy * 1.0,
      rx * 1.0,
      ry * 1.0,
      start_angle * 1.0,
      sweep_angle * 1.0,
      opts
    )
  end

  @doc """
  Same as `pie/8`, but returns the canvas and raises on error.
  """
  @spec pie!(
          canvas(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          opts()
        ) :: canvas()
  def pie!(canvas, cx, cy, rx, ry, start_angle, sweep_angle, opts \\ []) do
    case pie(canvas, cx, cy, rx, ry, start_angle, sweep_angle, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_pie, reason)
    end
  end

  @doc """
  Strokes a triangle specified by its three vertices.

  Uses the same stroke options as `path/3`.
  """
  @spec triangle(canvas(), number(), number(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def triangle(canvas, x0, y0, x1, y1, x2, y2, opts \\ []) do
    Native.canvas_stroke_triangle(
      canvas,
      x0 * 1.0,
      y0 * 1.0,
      x1 * 1.0,
      y1 * 1.0,
      x2 * 1.0,
      y2 * 1.0,
      opts
    )
  end

  @doc """
  Same as `triangle/8`, but returns the canvas and raises on error.
  """
  @spec triangle!(
          canvas(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          opts()
        ) :: canvas()
  def triangle!(canvas, x0, y0, x1, y1, x2, y2, opts \\ []) do
    case triangle(canvas, x0, y0, x1, y1, x2, y2, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_triangle, reason)
    end
  end

  @doc """
  Strokes a polyline given as a list of `{x, y}` points.

  Uses the same stroke options as `path/3`.
  """
  @spec polyline(canvas(), [{number(), number()}], opts()) ::
          :ok | {:error, term()}
  def polyline(canvas, points, opts \\ []) do
    Native.canvas_stroke_polyline(canvas, points, opts)
  end

  @doc """
  Same as `polyline/3`, but returns the canvas and raises on error.
  """
  @spec polyline!(canvas(), [{number(), number()}], opts()) :: canvas()
  def polyline!(canvas, points, opts \\ []) do
    case polyline(canvas, points, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_polyline, reason)
    end
  end

  @doc """
  Strokes a closed polygon given as a list of `{x, y}` points.

  Uses the same stroke options as `path/3`.
  """
  @spec polygon(canvas(), [{number(), number()}], opts()) ::
          :ok | {:error, term()}
  def polygon(canvas, points, opts \\ []) do
    Native.canvas_stroke_polygon(canvas, points, opts)
  end

  @doc """
  Same as `polygon/3`, but returns the canvas and raises on error.
  """
  @spec polygon!(canvas(), [{number(), number()}], opts()) :: canvas()
  def polygon!(canvas, points, opts \\ []) do
    case polygon(canvas, points, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_polygon, reason)
    end
  end

  @doc """
  Strokes multiple boxes in one call.

  `boxes` is a list of `{x0, y0, x1, y1}` tuples.

  Uses the same stroke options as `path/3`.
  """
  @spec box_array(canvas(), [{number(), number(), number(), number()}], opts()) ::
          :ok | {:error, term()}
  def box_array(canvas, boxes, opts \\ []) do
    Native.canvas_stroke_box_array(canvas, boxes, opts)
  end

  @doc """
  Same as `box_array/3`, but returns the canvas and raises on error.
  """
  @spec box_array!(canvas(), [{number(), number(), number(), number()}], opts()) :: canvas()
  def box_array!(canvas, boxes, opts \\ []) do
    case box_array(canvas, boxes, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_boxarray, reason)
    end
  end

  @doc """
  Strokes multiple rectangles in one call.

  `rects` is a list of `{x, y, w, h}` tuples.

  Uses the same stroke options as `path/3`.
  """
  @spec rect_array(canvas(), [{number(), number(), number(), number()}], opts()) ::
          :ok | {:error, term()}
  def rect_array(canvas, rects, opts \\ []) do
    Native.canvas_stroke_rect_array(canvas, rects, opts)
  end

  @doc """
  Same as `rect_array/3`, but returns the canvas and raises on error.
  """
  @spec rect_array!(canvas(), [{number(), number(), number(), number()}], opts()) :: canvas()
  def rect_array!(canvas, rects, opts \\ []) do
    case rect_array(canvas, rects, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_rectarray, reason)
    end
  end

  # ===========================================================================
  # Text
  # ===========================================================================

  @doc """
  Strokes a UTF-8 `text` string on `canvas` using `font`.

  Draws the text with its origin at `(x, y)`.

  `opts` reuses the same stroke options as `path/3`
  (`:stroke_color`, `:stroke_width`, etc.).

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec utf8_text(
          canvas(),
          Blendend.Text.Font.t(),
          number(),
          number(),
          String.t(),
          opts()
        ) :: :ok | {:error, term()}
  def utf8_text(canvas, font, x, y, text, opts \\ []) do
    Native.canvas_stroke_utf8_text(canvas, font, x * 1.0, y * 1.0, text, opts)
  end

  @doc """
  Same as `utf8_text/6`, but returns the canvas and raises on error.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec utf8_text!(
          canvas(),
          Blendend.Text.Font.t(),
          number(),
          number(),
          String.t(),
          opts()
        ) :: canvas()
  def utf8_text!(canvas, font, x, y, text, opts \\ []) do
    case utf8_text(canvas, font, x, y, text, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_utf8_text, reason)
    end
  end
end
