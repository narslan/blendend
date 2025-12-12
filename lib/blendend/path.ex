defmodule Blendend.Path do
  @moduledoc """
  A path is a collection of contours built from commands such as
  `:move_to`, `:line_to`, `:quad_to`, `:cubic_to`, and `:close`.

  We typically:

    * construct a path with `new/0` (or `new!/0`)
    * add segments with `move_to/3`, `line_to/3`, `quad_to/5`,
      `cubic_to/7`, `arc_quadrant_to/5`, `conic_to/6`, `arc_to/8`,
      `elliptic_arc_to/8`, or geometry helpers like `add_box/6`,
      `add_rect/6`, `add_circle/5`, `add_ellipse/6`,
      `add_round_rect/8`, `add_arc/8`, `add_chord/8`,
      `add_line/6`, `add_triangle/8`, `add_polyline/3`, or `add_polygon/3`
    * optionally inspect or deform it with `vertex_count/1`,
      `vertex_at/2`, and `set_vertex_at/5`
    * derive straight segments or samples with `segments/1` and `sample/3`
    * compose shapes with `add_path/2` and `add_path/3`
    * shift or warp them in-place via `translate/3`, `translate/4`,
      `transform/2`, or `transform/3`
    * derive stroke outlines as geometry with `add_stroked_path/3`
    * render it with `Blendend.Canvas.Fill.path/3` or
      `Blendend.Canvas.Stroke.path/3`
    * apply blur/shadow effect on it via `Blendend.Effects.blur_path/4`

  You can also build paths with the DSL in `Blendend.Draw`:

      use Blendend.Draw

      path badge do
        add_round_rect(20, 20, 140, 80, 12, 12)
        add_circle(60, 60, 18)
        add_line(20, 20, 160, 100)
      end

      stroke_path badge

  ## Segment commands vs. shape helpers

  There are two families of path builders:

    * `*_to` segment commands (`move_to/3`, `line_to/3`, `quad_to/5`,
      `cubic_to/7`, `arc_to/8`, `elliptic_arc_to/8`, etc.) append to the
      *current* contour. They expect a current point (set by `move_to/3` or a
      previous segment), do not auto-close, and keep the contour continuous.
      Reach for these when you need fine-grained control over how a path
      progresses or must preserve tangents between segments.
    * `add_*` shape helpers (`add_line/6`, `add_arc/8`, `add_circle/5`,
      `add_rect/6`, `add_polygon/3`, etc.) drop one or more self-contained
      figures into the path. They start their own contour(s) regardless of the
      current point, handle their own `move_to/close` sequence, and accept
      `:direction`/`:matrix` options for winding and transforms. Use these when
      you just need standard geometry stamped into a path without worrying about
      continuity with the previous segment.
  """

  @typedoc "Opaque path resource (sequence of lines/curves). Build via DSL or Path.*! helpers."
  @opaque t :: reference()
  @type point :: {float(), float()}
  @type segment :: {point(), point()}
  @type sampled_point :: {point(), {float(), float()}}
  @type hit_class :: :in | :out | :part
  @type direction :: :cw | :ccw | :none

  alias Blendend.Native
  alias Blendend.Error
  alias Blendend.Matrix2D

  # ===========================================================================
  # Construction
  # ===========================================================================

  @doc """
  Creates a new, empty path.

  On success, returns `{:ok, path}`.

  On failure, returns `{:error, reason}`.
  """
  @spec new() :: {:ok, t()} | {:error, term()}
  def new, do: Native.path_new()

  @doc """
  Same as `new/0`, but returns the path directly.

  On success, returns the path.

  On failure, raises `Blendend.Error`.
  """
  @spec new!() :: t()
  def new! do
    case new() do
      {:ok, path} -> path
      {:error, reason} -> raise Error.new(:path_new, reason)
    end
  end

  # ===========================================================================
  # Building commands
  # ===========================================================================

  @doc """
  Starts a new contour at `(x, y)`.

  This is equivalent to a `:move_to` command in the underlying path.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec move_to(t(), number(), number()) :: :ok | {:error, term()}
  def move_to(path, x, y), do: Native.path_move_to(path, x * 1.0, y * 1.0)

  @doc """
  Same as `move_to/3`, but returns the path.

  On failure, raises `Blendend.Error`.
  """
  @spec move_to!(t(), number(), number()) :: t()
  def move_to!(path, x, y) do
    case move_to(path, x, y) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_move_to, reason)
    end
  end

  @doc """
  Adds a straight line segment from the current point to `(x, y)`.

  The path must already have a current point (for example from a
  previous `move_to/3` or other drawing command).

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec line_to(t(), number(), number()) :: :ok | {:error, term()}
  def line_to(path, x, y), do: Native.path_line_to(path, x * 1.0, y * 1.0)

  @doc """
  Same as `line_to/3`, but returns the path .

  On success, returns the same `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec line_to!(t(), number(), number()) :: t()
  def line_to!(path, x, y) do
    case line_to(path, x, y) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_line_to, reason)
    end
  end

  @doc """
  Adds a quadratic Bézier curve to `(x2, y2)` with a single control
  point at `(x1, y1)`.

  This is equivalent to a `:quad_to` command.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec quad_to(t(), number(), number(), number(), number()) ::
          :ok | {:error, term()}
  def quad_to(path, x1, y1, x2, y2),
    do: Native.path_quad_to(path, x1 * 1.0, y1 * 1.0, x2 * 1.0, y2 * 1.0)

  @doc """
  Same as `quad_to/5`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec quad_to!(t(), number(), number(), number(), number()) :: t()
  def quad_to!(path, x1, y1, x2, y2) do
    case quad_to(path, x1, y1, x2, y2) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_quad_to, reason)
    end
  end

  @doc """
  Adds a **rational quadratic Bézier** segment to the path.

  Extends the current contour from the current point to `(x2, y2)` with a
  quadratic curve that has control point `(x1, y1)` and a *weight* `w`.

    * When `w == 1.0` it behaves like a standard quadratic curve.
    * Other weights bend the curve closer to or further from the control
      point, which is useful for arcs and circular approximations.

  The path must already have a current point.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec conic_to(t(), number(), number(), number(), number(), number()) ::
          :ok | {:error, term()}
  def conic_to(path, x1, y1, x2, y2, w),
    do: Native.path_conic_to(path, x1 * 1.0, y1 * 1.0, x2 * 1.0, y2 * 1.0, w * 1.0)

  @doc """
  Same as `conic_to/6`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec conic_to!(t(), number(), number(), number(), number(), number()) :: t()
  def conic_to!(path, x1, y1, x2, y2, w) do
    case conic_to(path, x1, y1, x2, y2, w) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_conic_to, reason)
    end
  end

  @doc """
  Adds a cubic Bézier curve to `(x3, y3)` with control points
  `(x1, y1)` and `(x2, y2)`.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec cubic_to(t(), number(), number(), number(), number(), number(), number()) ::
          :ok | {:error, term()}
  def cubic_to(path, x1, y1, x2, y2, x3, y3),
    do: Native.path_cubic_to(path, x1 * 1.0, y1 * 1.0, x2 * 1.0, y2 * 1.0, x3 * 1.0, y3 * 1.0)

  @doc """
  Same as `cubic_to/7`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec cubic_to!(t(), number(), number(), number(), number(), number(), number()) :: t()
  def cubic_to!(path, x1, y1, x2, y2, x3, y3) do
    case cubic_to(path, x1, y1, x2, y2, x3, y3) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_cubic_to, reason)
    end
  end

  @doc """
  Continues a **quadratic Bézier** smoothly from the previous segment.

  Wraps blend2d `smoothQuadTo` (like SVG `T`):

    * If the previous segment was a quadratic curve, the missing control
      point is mirrored across the current point to keep the curve smooth.
    * If there is no previous quadratic, the current point is used as the
      control point.

  The segment ends at `(x2, y2)`.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec smooth_quad_to(t(), number(), number()) :: :ok | {:error, term()}
  def smooth_quad_to(path, x2, y2),
    do: Native.path_smooth_quad_to(path, x2 * 1.0, y2 * 1.0)

  @doc """
  Same as `smooth_quad_to/3`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec smooth_quad_to!(t(), number(), number()) :: t()
  def smooth_quad_to!(path, x2, y2) do
    case smooth_quad_to(path, x2, y2) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_smooth_quad_to, reason)
    end
  end

  @doc """
  Continues a **cubic Bézier** smoothly from the previous segment.

  Wraps blend2d `smoothCubicTo` (like SVG `S`):

    * If the previous segment was cubic, the first control point of this
      segment is the mirror of the previous segment's second control point
      across the current point.
    * This gives a visually smooth tangent across the join.

  The segment ends at `(x3, y3)` and uses `(x2, y2)` as the second control
  point.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec smooth_cubic_to(t(), number(), number(), number(), number()) ::
          :ok | {:error, term()}
  def smooth_cubic_to(path, x2, y2, x3, y3),
    do: Native.path_smooth_cubic_to(path, x2 * 1.0, y2 * 1.0, x3 * 1.0, y3 * 1.0)

  @doc """
  Same as `smooth_cubic_to/5`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec smooth_cubic_to!(t(), number(), number(), number(), number()) :: t()
  def smooth_cubic_to!(path, x2, y2, x3, y3) do
    case smooth_cubic_to(path, x2, y2, x3, y3) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_smooth_cubic_to, reason)
    end
  end

  @doc """
  Adds a **circular or elliptical arc** segment to the path.

  Wraps blend2d's `arcTo`. Parameters:

    * `cx, cy` – center of the ellipse
    * `rx, ry` – radii in x and y
    * `start`  – start angle in radians
    * `sweep`  – sweep angle in radians
    * `force_move?` – when `true`, starts a new sub-path at the arc's
      start point instead of connecting from the current point

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec arc_to(
          t(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          boolean()
        ) :: :ok | {:error, term()}
  def arc_to(path, cx, cy, rx, ry, start, sweep, force_move? \\ false),
    do:
      Native.path_arc_to(
        path,
        cx * 1.0,
        cy * 1.0,
        rx * 1.0,
        ry * 1.0,
        start * 1.0,
        sweep * 1.0,
        force_move?
      )

  @doc """
  Same as `arc_to/8`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec arc_to!(
          t(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          boolean()
        ) :: t()
  def arc_to!(path, cx, cy, rx, ry, start, sweep, force_move? \\ false) do
    case arc_to(path, cx, cy, rx, ry, start, sweep, force_move?) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_arc_to, reason)
    end
  end

  @doc """
  Adds an **endpoint-based elliptical arc** to the path.

  Wraps blend2d's `ellipticArcTo` (similar to SVG `A`):

    * `rx, ry`       – ellipse radii
    * `rot`          – x-axis rotation in radians
    * `large?`       – large-arc flag
    * `sweep?`       – sweep direction flag
    * `x1, y1`       – endpoint of the arc

  The start point is the current point in the path.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec elliptic_arc_to(
          t(),
          number(),
          number(),
          number(),
          boolean(),
          boolean(),
          number(),
          number()
        ) :: :ok | {:error, term()}
  def elliptic_arc_to(path, rx, ry, rot, large?, sweep?, x1, y1),
    do:
      Native.path_elliptic_arc_to(
        path,
        rx * 1.0,
        ry * 1.0,
        rot * 1.0,
        large?,
        sweep?,
        x1 * 1.0,
        y1 * 1.0
      )

  @doc """
  Same as `elliptic_arc_to/8`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec elliptic_arc_to!(
          t(),
          number(),
          number(),
          number(),
          boolean(),
          boolean(),
          number(),
          number()
        ) :: t()
  def elliptic_arc_to!(path, rx, ry, rot, large?, sweep?, x1, y1) do
    case elliptic_arc_to(path, rx, ry, rot, large?, sweep?, x1, y1) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_elliptic_arc_to, reason)
    end
  end

  @doc """
  Adds a single 90° arc segment between two points.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec arc_quadrant_to(t(), number(), number(), number(), number()) ::
          :ok | {:error, term()}
  def arc_quadrant_to(path, x1, y1, x2, y2),
    do: Native.path_arc_quadrant_to(path, x1 * 1.0, y1 * 1.0, x2 * 1.0, y2 * 1.0)

  @doc """
  Same as `arc_quadrant_to/5`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec arc_quadrant_to!(t(), number(), number(), number(), number()) :: t()
  def arc_quadrant_to!(path, x1, y1, x2, y2) do
    case arc_quadrant_to(path, x1, y1, x2, y2) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_arc_quadrant_to, reason)
    end
  end

  @doc """
  Appends all contours from `src` into `dst`.

  Mutates `dst` in-place and leaves `src` unchanged.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec add_path(t(), t()) :: :ok | {:error, term()}
  def add_path(dst, src), do: Native.path_add_path(dst, src)

  @doc """
  Same as `add_path/2`, but returns `dst` .

  On success, returns `dst`.

  On failure, raises `Blendend.Error`.
  """
  @spec add_path!(t(), t()) :: t()
  def add_path!(dst, src) do
    case add_path(dst, src) do
      :ok -> dst
      {:error, reason} -> raise Error.new(:path_add_path, reason)
    end
  end

  @doc """
  Appends `src` into `dst` after applying an affine transform `mtx`.

  Mutates `dst` in-place and leaves `src` unchanged.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec add_path(t(), t(), Matrix2D.t()) :: :ok | {:error, term()}
  def add_path(dst, src, mtx),
    do: Native.path_add_path_transform(dst, src, mtx)

  @doc """
  Same as `add_path/3`, but returns `dst` .

  On success, returns `dst`.

  On failure, raises `Blendend.Error`.
  """
  @spec add_path!(t(), t(), Matrix2D.t()) :: t()
  def add_path!(dst, src, mtx) do
    case add_path(dst, src, mtx) do
      :ok -> dst
      {:error, reason} -> raise Error.new(:path_add_path_transform, reason)
    end
  end

  @doc """
  Runs Blend2D's stroker on `src` and appends the resulting outline
  geometry to `dst`.

  This does **not** draw anything; it converts a stroke into fillable
  path geometry. 

  `stroke_opts` (keyword list) mirrors `Blendend.Canvas.Stroke.path/2`:

    * `:width` – stroke width (float, default `1.0`)
    * `:miter_limit` – miter limit (default `4.0`)
    * `:start_cap` / `:end_cap` – `:butt | :round | :square | :round_rev | :triangle | :triangle_rev`
    * `:join` – `:miter_clip | :miter_bevel | :miter_round | :bevel | :round`
    * `:transform_order` – `:after | :before` (default `:after`)

  `approx_opts` (keyword list) maps to `BLApproximationOptions`:

    * `:flatten_tolerance`, `:simplify_tolerance`, `:offset_parameter`
    * `:flatten_mode` – `:default | :recursive`
    * `:offset_mode` – `:default | :iterative`

  ## Examples

      iex> alias Blendend.Path
      iex> src = Path.new!() |> Path.move_to!(20, 20) |> Path.line_to!(80, 20)
      iex> outline = Path.new!()
      iex> :ok = Path.add_stroked_path(outline, src, stroke_width: 6.0, join: :round)
      iex> Path.vertex_count!(outline) > Path.vertex_count!(src)
      true

  On success, returns `:ok`. On failure, returns `{:error, reason}`.
  """
  @spec add_stroked_path(t(), t(), keyword(), keyword()) :: :ok | {:error, term()}
  def add_stroked_path(dst, src, stroke_opts \\ [], approx_opts \\ []) do
    Native.path_add_stroked_path(dst, src, stroke_opts, approx_opts)
  end

  @doc """
  Same as `add_stroked_path/4`, but limits stroking to a vertex `range`
  (tuple `{start, stop}` or `Range`, stop exclusive).
  """
  @spec add_stroked_path(
          t(),
          t(),
          Range.t() | {non_neg_integer(), non_neg_integer()},
          keyword(),
          keyword()
        ) :: :ok | {:error, term()}
  def add_stroked_path(dst, src, range, stroke_opts, approx_opts) do
    Native.path_add_stroked_path(dst, src, range, stroke_opts, approx_opts)
  end

  @doc """
  Same as `add_stroked_path/4`, but returns the path directly.
  """
  @spec add_stroked_path!(t(), t(), keyword(), keyword()) :: t()
  def add_stroked_path!(dst, src, stroke_opts \\ [], approx_opts \\ []) do
    case add_stroked_path(dst, src, stroke_opts, approx_opts) do
      :ok -> dst
      {:error, reason} -> raise Error.new(:path_add_stroked_path, reason)
    end
  end

  @doc """
  Same as `add_stroked_path/5`, but returns the path directly.
  """
  @spec add_stroked_path!(
          t(),
          t(),
          Range.t() | {non_neg_integer(), non_neg_integer()},
          keyword(),
          keyword()
        ) :: t()
  def add_stroked_path!(dst, src, range, stroke_opts, approx_opts) do
    case add_stroked_path(dst, src, range, stroke_opts, approx_opts) do
      :ok -> dst
      {:error, reason} -> raise Error.new(:path_add_stroked_path, reason)
    end
  end

  @doc """
  Translates all vertices in the path by `(dx, dy)` in-place.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec translate(t(), number(), number()) :: :ok | {:error, term()}
  def translate(path, dx, dy), do: Native.path_translate(path, dx * 1.0, dy * 1.0)

  @doc """
  Translates only the vertices within `range` by `(dx, dy)`.

  `range` can be either a two-tuple `{start, stop}` (zero-based, stop is
  exclusive) or an Elixir `Range` struct.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec translate(t(), Range.t() | {non_neg_integer(), non_neg_integer()}, number(), number()) ::
          :ok | {:error, term()}
  def translate(path, range, dx, dy),
    do: Native.path_translate(path, range, dx * 1.0, dy * 1.0)

  @doc """
  Same as `translate/3`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec translate!(t(), number(), number()) :: t()
  def translate!(path, dx, dy) do
    case translate(path, dx, dy) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_translate, reason)
    end
  end

  @doc """
  Same as `translate/4`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec translate!(t(), Range.t() | {non_neg_integer(), non_neg_integer()}, number(), number()) ::
          t()
  def translate!(path, range, dx, dy) do
    case translate(path, range, dx, dy) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_translate, reason)
    end
  end

  @doc """
  Transforms the whole path by matrix m.

  Mutates the path in-place. Wraps `BLPath::transform(matrix)`.
  """
  @spec transform(t(), Matrix2D.t()) :: :ok | {:error, term()}
  def transform(path, matrix), do: Native.path_transform(path, matrix)

  @doc """
  Applies an affine transform `matrix` only to the vertices within `range`.

  `range` accepts a two-tuple `{start, stop}` (zero-based, stop exclusive)
  or an Elixir `Range`.
  """
  @spec transform(t(), Range.t() | {non_neg_integer(), non_neg_integer()}, Matrix2D.t()) ::
          :ok | {:error, term()}
  def transform(path, range, matrix), do: Native.path_transform(path, range, matrix)

  @doc """
  Same as `transform/2`, but returns the path .
  """
  @spec transform!(t(), Matrix2D.t()) :: t()
  def transform!(path, matrix) do
    case transform(path, matrix) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_transform, reason)
    end
  end

  @doc """
  Same as `transform/3`, but returns the path .
  """
  @spec transform!(t(), Range.t() | {non_neg_integer(), non_neg_integer()}, Matrix2D.t()) :: t()
  def transform!(path, range, matrix) do
    case transform(path, range, matrix) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_transform, reason)
    end
  end

  @doc """
  Adds a closed rectangular box defined by corners `(x0, y0)` and `(x1, y1)`.

  Optional `opts`:

    * `:matrix`    – `t:Blendend.Matrix2D.t/0` transform to apply
    * `:direction` – `:cw | :ccw | :none` (default: `:cw`)

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec add_box(t(), number(), number(), number(), number(), keyword()) :: :ok | {:error, term()}
  def add_box(path, x0, y0, x1, y1, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)
    Native.path_add_box(path, x0 * 1.0, y0 * 1.0, x1 * 1.0, y1 * 1.0, matrix || nil, dir)
  end

  @doc """
  Same as `add_box/6`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec add_box!(t(), number(), number(), number(), number(), keyword()) :: t()
  def add_box!(path, x0, y0, x1, y1, opts \\ []) do
    case add_box(path, x0, y0, x1, y1, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_box, reason)
    end
  end

  @doc """
  Adds a closed rectangle `(x, y, w, h)`.

  Accepts the same optional `opts` as `add_box/6`.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec add_rect(t(), number(), number(), number(), number(), keyword()) :: :ok | {:error, term()}
  def add_rect(path, x, y, w, h, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)
    Native.path_add_rect(path, x * 1.0, y * 1.0, w * 1.0, h * 1.0, matrix || nil, dir)
  end

  @doc """
  Same as `add_rect/6`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec add_rect!(t(), number(), number(), number(), number(), keyword()) :: t()
  def add_rect!(path, x, y, w, h, opts \\ []) do
    case add_rect(path, x, y, w, h, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_rect, reason)
    end
  end

  @doc """
  Adds a closed circular contour centered at `(cx, cy)` with radius `r`.

  Optional `opts`:

    * `:matrix`    – `t:Blendend.Matrix2D.t/0` transform to apply
    * `:direction` – `:cw | :ccw | :none` (default: `:cw`)

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec add_circle(t(), number(), number(), number(), keyword()) :: :ok | {:error, term()}
  def add_circle(path, cx, cy, r, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)
    Native.path_add_circle(path, cx * 1.0, cy * 1.0, r * 1.0, matrix || nil, dir)
  end

  @doc """
  Same as `add_circle/5`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec add_circle!(t(), number(), number(), number(), keyword()) :: t()
  def add_circle!(path, cx, cy, r, opts \\ []) do
    case add_circle(path, cx, cy, r, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_circle, reason)
    end
  end

  @doc """
  Adds an ellipse centered at `(cx, cy)` with radii `(rx, ry)`.

  Accepts the same optional `opts` as `add_circle/5`.
  """
  @spec add_ellipse(t(), number(), number(), number(), number(), keyword()) ::
          :ok | {:error, term()}
  def add_ellipse(path, cx, cy, rx, ry, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)
    Native.path_add_ellipse(path, cx * 1.0, cy * 1.0, rx * 1.0, ry * 1.0, matrix || nil, dir)
  end

  @doc """
  Same as `add_ellipse/6`, but returns the path .
  """
  @spec add_ellipse!(t(), number(), number(), number(), number(), keyword()) :: t()
  def add_ellipse!(path, cx, cy, rx, ry, opts \\ []) do
    case add_ellipse(path, cx, cy, rx, ry, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_ellipse, reason)
    end
  end

  @doc """
  Adds a rounded rectangle `(x, y, w, h, rx, ry)`.

  Accepts the same optional `opts` as `add_circle/5`.
  """
  @spec add_round_rect(t(), number(), number(), number(), number(), number(), number(), keyword()) ::
          :ok | {:error, term()}
  def add_round_rect(path, x, y, w, h, rx, ry, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)

    Native.path_add_round_rect(
      path,
      x * 1.0,
      y * 1.0,
      w * 1.0,
      h * 1.0,
      rx * 1.0,
      ry * 1.0,
      matrix || nil,
      dir
    )
  end

  @doc """
  Same as `add_round_rect/8`, but returns the path .
  """
  @spec add_round_rect!(
          t(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          keyword()
        ) :: t()
  def add_round_rect!(path, x, y, w, h, rx, ry, opts \\ []) do
    case add_round_rect(path, x, y, w, h, rx, ry, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_round_rect, reason)
    end
  end

  @doc """
  Adds an arc defined by `(cx, cy, rx, ry, start, sweep)`.

  Accepts the same optional `opts` as `add_circle/5`.
  """
  @spec add_arc(t(), number(), number(), number(), number(), number(), number(), keyword()) ::
          :ok | {:error, term()}
  def add_arc(path, cx, cy, rx, ry, start, sweep, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)

    Native.path_add_arc(
      path,
      cx * 1.0,
      cy * 1.0,
      rx * 1.0,
      ry * 1.0,
      start * 1.0,
      sweep * 1.0,
      matrix || nil,
      dir
    )
  end

  @doc """
  Same as `add_arc/8`, but returns the path .
  """
  @spec add_arc!(
          t(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          keyword()
        ) :: t()
  def add_arc!(path, cx, cy, rx, ry, start, sweep, opts \\ []) do
    case add_arc(path, cx, cy, rx, ry, start, sweep, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_arc, reason)
    end
  end

  @doc """
  Adds a chord (closed arc) defined by `(cx, cy, rx, ry, start, sweep)`.

  Accepts the same optional `opts` as `add_circle/5`.
  """
  @spec add_chord(t(), number(), number(), number(), number(), number(), number(), keyword()) ::
          :ok | {:error, term()}
  def add_chord(path, cx, cy, rx, ry, start, sweep, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)

    Native.path_add_chord(
      path,
      cx * 1.0,
      cy * 1.0,
      rx * 1.0,
      ry * 1.0,
      start * 1.0,
      sweep * 1.0,
      matrix || nil,
      dir
    )
  end

  @doc """
  Same as `add_chord/8`, but returns the path .
  """
  @spec add_chord!(
          t(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          keyword()
        ) :: t()
  def add_chord!(path, cx, cy, rx, ry, start, sweep, opts \\ []) do
    case add_chord(path, cx, cy, rx, ry, start, sweep, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_chord, reason)
    end
  end

  @doc """
  Adds a line segment between `(x0, y0)` and `(x1, y1)` as a figure.

  Accepts the same optional `opts` as `add_circle/5`.
  """
  @spec add_line(t(), number(), number(), number(), number(), keyword()) :: :ok | {:error, term()}
  def add_line(path, x0, y0, x1, y1, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)
    Native.path_add_line(path, x0 * 1.0, y0 * 1.0, x1 * 1.0, y1 * 1.0, matrix || nil, dir)
  end

  @doc """
  Same as `add_line/6`, but returns the path .
  """
  @spec add_line!(t(), number(), number(), number(), number(), keyword()) :: t()
  def add_line!(path, x0, y0, x1, y1, opts \\ []) do
    case add_line(path, x0, y0, x1, y1, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_line, reason)
    end
  end

  @doc """
  Adds a closed triangle `(x0, y0)`, `(x1, y1)`, `(x2, y2)`.

  Accepts the same optional `opts` as `add_circle/5`.
  """
  @spec add_triangle(
          t(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          keyword()
        ) :: :ok | {:error, term()}
  def add_triangle(path, x0, y0, x1, y1, x2, y2, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)

    Native.path_add_triangle(
      path,
      x0 * 1.0,
      y0 * 1.0,
      x1 * 1.0,
      y1 * 1.0,
      x2 * 1.0,
      y2 * 1.0,
      matrix || nil,
      dir
    )
  end

  @doc """
  Same as `add_triangle/8`, but returns the path .
  """
  @spec add_triangle!(
          t(),
          number(),
          number(),
          number(),
          number(),
          number(),
          number(),
          keyword()
        ) :: t()
  def add_triangle!(path, x0, y0, x1, y1, x2, y2, opts \\ []) do
    case add_triangle(path, x0, y0, x1, y1, x2, y2, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_triangle, reason)
    end
  end

  @doc """
  Adds a polyline defined by `points` (`[{x, y}, ...]`).

  Accepts the same optional `opts` as `add_circle/5`.
  """
  @spec add_polyline(t(), [point()], keyword()) :: :ok | {:error, term()}
  def add_polyline(path, points, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)
    float_points = normalize_points(points)
    Native.path_add_polyline(path, float_points, matrix || nil, dir)
  end

  @doc """
  Same as `add_polyline/3`, but returns the path .
  """
  @spec add_polyline!(t(), [point()], keyword()) :: t()
  def add_polyline!(path, points, opts \\ []) do
    case add_polyline(path, points, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_polyline, reason)
    end
  end

  @doc """
  Adds a polygon defined by `points` (`[{x, y}, ...]`).

  Accepts the same optional `opts` as `add_circle/5`.
  """
  @spec add_polygon(t(), [point()], keyword()) :: :ok | {:error, term()}
  def add_polygon(path, points, opts \\ []) do
    {matrix, dir} = normalize_geometry_opts(opts)
    float_points = normalize_points(points)
    Native.path_add_polygon(path, float_points, matrix || nil, dir)
  end

  @doc """
  Same as `add_polygon/3`, but returns the path .
  """
  @spec add_polygon!(t(), [point()], keyword()) :: t()
  def add_polygon!(path, points, opts \\ []) do
    case add_polygon(path, points, opts) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_add_polygon, reason)
    end
  end

  defp normalize_geometry_opts(opts) do
    dir = Keyword.get(opts, :direction, :cw)

    unless dir in [:cw, :ccw, :none] do
      raise ArgumentError, "direction must be one of :cw, :ccw, :none"
    end

    matrix = Keyword.get(opts, :matrix)

    if matrix != nil and not is_reference(matrix) do
      raise ArgumentError, "matrix must be a Matrix2D.t() or nil"
    end

    {matrix, dir}
  end

  defp normalize_points(points) do
    Enum.map(points, fn
      {x, y} -> {x * 1.0, y * 1.0}
      other -> raise ArgumentError, "point must be a {x, y} tuple, got: #{inspect(other)}"
    end)
  end

  @doc """
  Closes the current contour (adds a `:close` command).

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec close(t()) :: :ok | {:error, term()}
  def close(path), do: Native.path_close(path)

  @doc """
  Same as `close/1`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec close!(t()) :: t()
  def close!(path) do
    case close(path) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_close, reason)
    end
  end

  # ===========================================================================
  # Introspection and mutation
  # ===========================================================================

  @doc """
  Returns the number of vertices stored in `path`.

  On success, returns `{:ok, count}`.

  On failure, returns `{:error, reason}`.
  """
  @spec vertex_count(t()) :: {:ok, non_neg_integer()} | {:error, term()}
  def vertex_count(path), do: Native.path_vertex_count(path)

  @doc """
  Same as `vertex_count/1`, but returns the count directly.

  On success, returns `count`.

  On failure, raises `Blendend.Error`.
  """
  @spec vertex_count!(t()) :: non_neg_integer()
  def vertex_count!(path) do
    case vertex_count(path) do
      {:ok, n} -> n
      {:error, reason} -> raise Error.new(:path_vertex_count, reason)
    end
  end

  @doc """
  Returns the vertex at index `idx`.

  On success, returns `{:ok, {cmd, x, y}}` where:

    * `cmd` – atom like `:move_to`, `:line_to`, `:quad_to`, `:cubic_to`, `:close`
    * `x`, `y` – coordinates as floats

  On failure, returns `{:error, reason}`.
  """
  @spec vertex_at(t(), non_neg_integer()) ::
          {:ok, {atom(), float(), float()}} | {:error, term()}
  def vertex_at(path, idx), do: Native.path_vertex_at(path, idx)

  @doc """
  Same as `vertex_at/2`, but returns `{cmd, x, y}` directly.

  On success, returns `{cmd, x, y}`.

  On failure, raises `Blendend.Error`.
  """
  @spec vertex_at!(t(), non_neg_integer()) :: {atom(), float(), float()}
  def vertex_at!(path, idx) do
    case vertex_at(path, idx) do
      {:ok, triple} -> triple
      {:error, reason} -> raise Error.new(:path_vertex_at, reason)
    end
  end

  @doc """
  `set_vertex_at` lets you mutate an existing path,

  `idx` is zero-based; `cmd` controls how the vertex is interpreted.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec set_vertex_at(t(), non_neg_integer(), atom(), float(), float()) ::
          :ok | {:error, term()}
  def set_vertex_at(path, idx, cmd, x, y),
    do: Native.path_set_vertex_at(path, idx, cmd, x, y)

  @doc """
  Same as `set_vertex_at/5`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec set_vertex_at!(t(), non_neg_integer(), atom(), float(), float()) :: t()
  def set_vertex_at!(path, idx, cmd, x, y) do
    case set_vertex_at(path, idx, cmd, x, y) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_set_vertex_at, reason)
    end
  end

  @doc """
  Clears all vertices from the path.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec clear(t()) :: :ok | {:error, term()}
  def clear(path), do: Native.path_clear(path)

  @doc """
  Same as `clear/1`, but returns the path .

  On success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec clear!(t()) :: t()
  def clear!(path) do
    case clear(path) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_clear, reason)
    end
  end

  # ===========================================================================
  # Hit testing
  # ===========================================================================

  @doc """
  Hit-tests `(x, y)` against the path (fill rule: `:non_zero`).

  Returns `:in | :out | :part` on success.

  Raises `Blendend.Error` if the NIF reports `:invalid` (bad args, NaNs, etc.)
  or if an error tuple is returned.
  """
  @spec hit_test(t(), number(), number()) :: hit_class()
  def hit_test(path, x, y) do
    case Native.path_hit_test(path, x * 1.0, y * 1.0) do
      {:ok, :in} -> :in
      {:ok, :out} -> :out
      {:ok, :part} -> :part
      {:ok, :invalid} -> raise Error.new(:path_hit_test, :invalid)
      {:error, reason} -> raise Error.new(:path_hit_test, reason)
      other -> raise Error.new(:path_hit_test, {:unexpected_return, other})
    end
  end

  @doc """
  Hit-tests `(x, y)` using the given fill rule (`:non_zero | :even_odd`).

  Returns `:in | :out | :part` on success.

  Raises `Blendend.Error` if the NIF reports `:invalid` or an error.
  """

  @spec hit_test(t(), number(), number(), :non_zero | :even_odd) :: hit_class()
  def hit_test(path, x, y, rule) when rule in [:non_zero, :even_odd] do
    case Native.path_hit_test(path, x * 1.0, y * 1.0, rule) do
      {:ok, :in} -> :in
      {:ok, :out} -> :out
      {:ok, :part} -> :part
      {:ok, :invalid} -> raise Error.new(:path_hit_test, :invalid)
      {:error, reason} -> raise Error.new(:path_hit_test, reason)
      other -> raise Error.new(:path_hit_test, {:unexpected_return, other})
    end
  end

  @doc """
  Returns `true` if two paths are *exactly* equal.

  This is a strict, bit-for-bit comparison of the underlying data. Tiny
  floating point differences will make it return `false`.
  """
  @spec equal?(t(), t()) :: boolean()
  def equal?(path_a, path_b), do: Native.path_equals(path_a, path_b)

  @doc """
  Fits the path into the given rectangle `{x, y, w, h}`.

  Mutates the path in-place so its bounds fit inside the rectangle.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec fit_to(t(), {number(), number(), number(), number()}) ::
          :ok | {:error, term()}
  def fit_to(path, {x, y, w, h}),
    do: Native.path_fit_to(path, {x * 1.0, y * 1.0, w * 1.0, h * 1.0})

  @doc """
  Same as `fit_to/2`, but on success, returns `path`.

  On failure, raises `Blendend.Error`.
  """
  @spec fit_to!(t(), {number(), number(), number(), number()}) :: t()
  def fit_to!(path, rect) do
    case fit_to(path, rect) do
      :ok -> path
      {:error, reason} -> raise Error.new(:path_fit_to, reason)
    end
  end

  @doc """
  Returns a new path where all curves have been approximated
  by `:line_to` segments.

  The resulting path only contains `:move_to`, `:line_to`, and `:close`
  commands. The `tolerance` argument controls the approximation accuracy
  (default `0.25` user units).

  On success returns `{:ok, new_path}`.
  """
  @spec flatten(t(), number()) :: {:ok, t()} | {:error, term()}

  def flatten(path, tolerance) do
    Native.path_flatten(path, tolerance * 1.0)
  end

  @spec flatten!(t(), number()) :: t()
  def flatten!(path, tolerance \\ 0.25) do
    case flatten(path, tolerance) do
      {:ok, new_path} -> new_path
      {:error, reason} -> raise Error.new(:path_flatten, reason)
    end
  end

  @doc """
  Normalizes a path in-place by removing redundant vertices and simplifying its data.

  Wraps `BLPath.shrink/0`. Useful after stroking or bulk edits to compact the path buffer.
  """
  @spec shrink(t()) :: {:ok, t()} | {:error, term()}
  def shrink(path) do
    case Native.path_shrink(path) do
      :ok -> {:ok, path}
      {:error, reason} -> {:error, reason}
    end
  end

  @doc """
  Same as `shrink/1`, but raises on error.
  """
  @spec shrink!(t()) :: t()
  def shrink!(path) do
    case shrink(path) do
      {:ok, p} -> p
      {:error, reason} -> raise Error.new(:path_shrink, reason)
    end
  end

  # ===========================================================================
  # Derived geometry helpers
  # ===========================================================================

  @doc """
  Returns a list of straight `{{x0, y0}, {x1, y1}}` segments for every contour.

  Assumes the path only contains `:move_to`, `:line_to`, and `:close`
  commands. Call `flatten!/1` first if your path has curves. When a `:close`
  is seen, the last point is connected back to the contour start.

  Raises `ArgumentError` if a curve command (`:quad_to`, `:cubic_to`, etc.)
  is encountered or if the path is malformed (for example `:line_to` before
  any `:move_to`).
  """
  @spec segments(t()) :: [segment()]
  def segments(path) do
    count = vertex_count!(path)

    {segments, _last, _start} =
      0..(count - 1)
      |> Enum.map(&vertex_at!(path, &1))
      |> Enum.reduce({[], nil, nil}, fn
        {:move_to, x, y}, {acc, _last, _start} ->
          {acc, {x * 1.0, y * 1.0}, {x * 1.0, y * 1.0}}

        {:line_to, x, y}, {acc, {lx, ly}, start} ->
          {[{{lx, ly}, {x * 1.0, y * 1.0}} | acc], {x * 1.0, y * 1.0}, start}

        {:close, _, _}, {acc, last, start} when not is_nil(last) and not is_nil(start) ->
          {[{last, start} | acc], nil, nil}

        {cmd, _x, _y}, _acc ->
          raise ArgumentError,
                "Path.segments/1 expects only :move_to, :line_to, :close (got #{inspect(cmd)})"
      end)

    Enum.reverse(segments)
  end

  @doc """
  Samples points along a list of straight segments.

  Each returned item is `{{x, y}, {nx, ny}}` where `{nx, ny}` is the
  unit-length **left-hand** normal for the directed segment `{p0 -> p1}`
  (`{-dy/len, dx/len}`).

  Options:

    * `:include_ends?` (default: `true`) – include segment endpoints in sampling

  `spacing` must be positive. Zero-length segments are skipped.
  """
  @spec sample([segment()], number(), Keyword.t()) :: [sampled_point()]
  def sample(segments, spacing, opts \\ []) when spacing > 0 do
    include_ends? = Keyword.get(opts, :include_ends?, true)

    segments
    |> Enum.flat_map(&sample_segment(&1, spacing, include_ends?))
  end

  defp sample_segment({{x0, y0}, {x1, y1}}, spacing, include_ends?) do
    dx = x1 - x0
    dy = y1 - y0
    len = :math.sqrt(dx * dx + dy * dy)

    if len == 0.0 do
      []
    else
      steps = max(floor(len / spacing), 1)
      start_i = if include_ends?, do: 0, else: 1
      end_i = if include_ends?, do: steps, else: steps - 1
      nx = -dy / len
      ny = dx / len
      step = if start_i <= end_i, do: 1, else: -1
      range = Range.new(start_i, end_i, step)

      for i <- range,
          i >= 0 and i <= steps,
          t = min(1.0, i / steps) do
        {{x0 + dx * t, y0 + dy * t}, {nx, ny}}
      end
    end
  end

  @doc """
  Dumps internal path representation for debugging.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec debug_dump(t()) :: :ok | {:error, term()}
  def debug_dump(path), do: Native.path_debug_dump(path)

  @doc """
  Same as `debug_dump/1`, but raises on error.

  On success, returns `:ok`.

  On failure, raises `Blendend.Error`.

  ## Examples

      iex> p = Blendend.Path.new!()
      iex> p = Blendend.Path.move_to!(p, 247, 97)
      iex> Path.debug_dump!(p)
      :ok
      # prints:
      # [path_debug_dump] path size = 1
      # [  0] cmd=0 x=247.000000 y=97.000000
  """
  @spec debug_dump!(t()) :: :ok
  def debug_dump!(path) do
    case debug_dump(path) do
      :ok -> :ok
      {:error, reason} -> raise Error.new(:path_debug_dump, reason)
    end
  end
end
