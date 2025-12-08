defmodule Blendend.Canvas.Fill do
  @moduledoc """
  Fill functions for `Blendend.Canvas` to paint a 
  geometry on the canvas with a style (color, gradient or pattern).

  Prefer the `Blendend.Draw` macros; they call into this
  module under the hood.

      use Blendend.Draw

      draw 200, 200, "fill_example.png" do
        clear fill: rgb(240, 240, 240)

        rect 30, 30, 140, 140, fill: rgb(255, 80, 80)
        circle 100, 100, 40, fill: rgb(255, 255, 255), alpha: 0.7
      end
  """

  alias Blendend.{Native, Error}

  @type canvas :: Blendend.Canvas.t()
  @type opts :: keyword()

  @doc """
  Fills `path` on `canvas` using the given style options.

  `path` must be a `Blendend.Path.t()`.

  ## Style options

  The `opts` keyword list controls the fill style. The style layer currently
  understands:

    * `:fill`:     
        – solid brush, created with `Blendend.Style.Color.*`
        – gradient brush, created with `Blendend.Style.Gradient.*`
        – image pattern, created with `Blendend.Style.Pattern.create/1`
    * `:alpha`    – extra opacity multiplier (float, typically `0.0..1.0`)
    * `:comp_op`  – compositing operator atom (e.g. `:src_over`, `:multiply`, etc.)

  We normally provide exactly one brush with `:fill`
  and optionally decorate it with `:alpha` and/or `:comp_op`. If no brush is
  provided, the context’s current fill style is used.

  ## Examples

      alias Blendend.{Canvas, Path, Style}
      alias Blendend.Canvas.Fill
      canvas = Canvas.new!(200, 200)
      path =
        Path.new!()
        |> Path.move_to!(10, 10)
        |> Path.line_to!(190, 10)
        |> Path.line_to!(100, 180)
        |> Path.close!()
      :ok =
        Fill.path(canvas, path,
          fill: Style.color(255, 0, 0),
          alpha: 0.9,
          comp_op: :src_over)

  On success, returns `:ok`.

  On failure, returns `{:error, reason}` from the NIF.
  """
  @spec path(canvas(), Blendend.Path.t(), opts()) :: :ok | {:error, term()}
  def path(canvas, path, opts \\ []),
    do: Native.canvas_fill_path(canvas, path, opts)

  @doc """
  Same as `path/3`, but returns the canvas and raises on error.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec path!(canvas(), Blendend.Path.t(), opts()) :: canvas()
  def path!(canvas, path, opts \\ []) do
    case path(canvas, path, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_fill_path, reason)
    end
  end

  # ===========================================================================
  # Shapes
  # ===========================================================================

  @doc """
  Fills a box given by corner coordinates `{x0, y0, x1, y1}`.

  Uses the same style options as `path/3`.
  """
  @spec box(canvas(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def box(canvas, x0, y0, x1, y1, opts \\ []) do
    Native.canvas_fill_box(canvas, x0 * 1.0, y0 * 1.0, x1 * 1.0, y1 * 1.0, opts)
  end

  @doc """
  Same as `box/6`, but returns the canvas and raises on error.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec box!(canvas(), number(), number(), number(), number(), opts()) :: canvas()
  def box!(canvas, x0, y0, x1, y1, opts \\ []) do
    case box(canvas, x0, y0, x1, y1, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:fill_box, reason)
    end
  end

  @doc """
  Fills an axis–aligned rectangle `(x, y, w, h)`.

  `(x, y)` is the top–left corner; `w` and `h` are width and height.

  Uses the same style options as `path/3`.
  """
  @spec rect(canvas(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def rect(canvas, x, y, w, h, opts \\ []) do
    Native.canvas_fill_rect(canvas, x * 1.0, y * 1.0, w * 1.0, h * 1.0, opts)
  end

  @doc """
  Same as `rect/6`, but returns the canvas and raises on error.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec rect!(canvas(), number(), number(), number(), number(), opts()) :: canvas()
  def rect!(canvas, x, y, w, h, opts \\ []) do
    case rect(canvas, x, y, w, h, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:fill_rect, reason)
    end
  end

  @doc """
  Fills a circle at `(cx, cy)` with radius `r`.

  Uses the same style options as `path/3`.
  """
  @spec circle(canvas(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def circle(canvas, cx, cy, r, opts \\ []) do
    Native.canvas_fill_circle(canvas, cx * 1.0, cy * 1.0, r * 1.0, opts)
  end

  @doc """
  Same as `circle/5`, but returns the canvas and raises on error.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec circle!(canvas(), number(), number(), number(), opts()) :: canvas()
  def circle!(canvas, cx, cy, r, opts \\ []) do
    case circle(canvas, cx, cy, r, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:fill_circle, reason)
    end
  end

  @doc """
  Fills an ellipse centered at `(cx, cy)` with radii `rx` and `ry`.

  Uses the same style options as `path/3`.
  """
  @spec ellipse(canvas(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def ellipse(canvas, cx, cy, rx, ry, opts \\ []) do
    Native.canvas_fill_ellipse(canvas, cx * 1.0, cy * 1.0, rx * 1.0, ry * 1.0, opts)
  end

  @doc """
  Same as `ellipse/6`, but returns the canvas and raises on error.
  """
  @spec ellipse!(canvas(), number(), number(), number(), number(), opts()) :: canvas()
  def ellipse!(canvas, cx, cy, rx, ry, opts \\ []) do
    case ellipse(canvas, cx, cy, rx, ry, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:fill_ellipse, reason)
    end
  end

  @doc """
  Fills a rounded rectangle `(x, y, w, h)` with corner radii `(rx, ry)`.

  Uses the same style options as `path/3`.
  """
  @spec round_rect(canvas(), number(), number(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def round_rect(canvas, x, y, w, h, rx, ry, opts \\ []) do
    Native.canvas_fill_round_rect(
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
      {:error, reason} -> raise Error.new(:fill_round_rect, reason)
    end
  end

  @doc """
  Fills a chord (arc + straight line between its endpoints).

  Parameters describe an ellipse centered at `(cx, cy)` with radii `rx`, `ry`
  and angles `start_angle` / `sweep_angle` in radians.

  Uses the same style options as `path/3`.
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
    Native.canvas_fill_chord(
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
      {:error, reason} -> raise Error.new(:fill_chord, reason)
    end
  end

  @doc """
  Fills a pie/sector shape.

  Same parameters as `chord/8`, but the arc is also connected back to the
  ellipse center.

  Uses the same style options as `path/3`.
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
    Native.canvas_fill_pie(
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
      {:error, reason} -> raise Error.new(:fill_pie, reason)
    end
  end

  @doc """
  Fills a triangle specified by its three vertices.

  Uses the same style options as `path/3`.
  """
  @spec triangle(canvas(), number(), number(), number(), number(), number(), number(), opts()) ::
          :ok | {:error, term()}
  def triangle(canvas, x0, y0, x1, y1, x2, y2, opts \\ []) do
    Native.canvas_fill_triangle(
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
      {:error, reason} -> raise Error.new(:fill_triangle, reason)
    end
  end

  @doc """
  Fills a polygon from a list of `{x, y}` points.

  Uses the same style options as `path/3`.
  """
  @spec polygon(canvas(), [{number(), number()}], opts()) ::
          :ok | {:error, term()}
  def polygon(canvas, points, opts \\ []) do
    Native.canvas_fill_polygon(canvas, points, opts)
  end

  @doc """
  Same as `polygon/3`, but returns the canvas and raises on error.
  """
  @spec polygon!(canvas(), [{number(), number()}], opts()) :: canvas()
  def polygon!(canvas, points, opts \\ []) do
    case polygon(canvas, points, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:fill_polygon, reason)
    end
  end

  @doc """
  Fills multiple boxes in one call.

  `boxes` is a list of `{x0, y0, x1, y1}` tuples.

  Uses the same style options as `path/3`.
  """
  @spec box_array(canvas(), [{number(), number(), number(), number()}], opts()) ::
          :ok | {:error, term()}
  def box_array(canvas, boxes, opts \\ []) do
    Native.canvas_fill_box_array(canvas, boxes, opts)
  end

  @doc """
  Same as `box_array/3`, but returns the canvas and raises on error.
  """
  @spec box_array!(canvas(), [{number(), number(), number(), number()}], opts()) :: canvas()
  def box_array!(canvas, boxes, opts \\ []) do
    case box_array(canvas, boxes, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:fill_box_array, reason)
    end
  end

  @doc """
  Fills multiple rectangles in one call.

  `rects` is a list of `{x, y, w, h}` tuples.

  Uses the same style options as `path/3`.
  """
  @spec rect_array(canvas(), [{number(), number(), number(), number()}], opts()) ::
          :ok | {:error, term()}
  def rect_array(canvas, rects, opts \\ []) do
    Native.canvas_fill_rect_array(canvas, rects, opts)
  end

  @doc """
  Same as `rect_array/3`, but returns the canvas and raises on error.
  """
  @spec rect_array!(canvas(), [{number(), number(), number(), number()}], opts()) :: canvas()
  def rect_array!(canvas, rects, opts \\ []) do
    case rect_array(canvas, rects, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:fill_rect_array, reason)
    end
  end

  # ===========================================================================
  # Text
  # ===========================================================================

  @doc """
  Fills a UTF-8 `text` string on `canvas` using a `font`.

  Draws the text with its origin at `(x, y)` in the current canvas transform.

  `opts` is the same style keyword list used by `path/3` (for example
  `:color`, `:gradient`, `:alpha`, `:comp_op`).

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
    Native.canvas_fill_utf8_text(canvas, font, x * 1.0, y * 1.0, text, opts)
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
      {:error, reason} -> raise Error.new(:fill_utf8_text, reason)
    end
  end
end
