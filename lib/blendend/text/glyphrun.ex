defmodule Blendend.Text.GlyphRun do
  @moduledoc """
  A glyph run is a view over a sequence of glyphs (IDs and positions)
  that have already been shaped by a font.

  Typical flow:

    * put UTF-8 text into a `GlyphBuffer`,
    * call `Blendend.Text.Font.shape/2`,
    * construct a `GlyphRun` from that buffer with `GlyphRun.new/1`,
    * render it with `fill/6` or `stroke/6`, or outline it.

  """

  @opaque t :: reference()

  alias Blendend.Native
  alias Blendend.Error
  alias Blendend.Text.GlyphBuffer

  @spec new(GlyphBuffer.t()) :: {:ok, t()} | {:error, term()}
  def new(gb), do: Native.glyph_run_new(gb)

  @spec new!(GlyphBuffer.t()) :: t()
  def new!(gb) do
    case new(gb) do
      {:ok, run} -> run
      {:error, reason} -> raise Error.new(:glyph_run_new, reason)
    end
  end

  @doc """
  Fills the glyph run on `canvas` using the given `font`.

  The glyphs in `glyph_run` are taken as already shaped for `font`. The run
  is drawn with its origin at `(x0, y0)` in the current canvas transform.

  `opts` is a style keyword list and supports the same options as
  `Blendend.Canvas.Fill.path/3` (for example `:color`, `:gradient`,
  `:alpha`, `:comp_op`, etc.).

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec fill(
          Blendend.Canvas.t(),
          Blendend.Text.Font.t(),
          number(),
          number(),
          t(),
          keyword()
        ) :: :ok | {:error, term()}
  def fill(canvas, font, x0, y0, glyph_run, opts \\ []),
    do: Native.fill_glyph_run(canvas, font, x0 * 1.0, y0 * 1.0, glyph_run, opts)

  @doc """
  Same as `fill/6`, but returns the canvas and raises on error.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.

  This is the typical end of the manual glyph pipeline:

      alias Blendend.Text.{Face, Font, GlyphBuffer, GlyphRun}
      alias Blendend.{Canvas, Style, Matrix2D}

      face = Face.load!("priv/fonts/Alegreya-Regular.otf")
      font = Font.create!(face, 42.0)
      canvas = Canvas.new!(800, 200)

      gb =
        GlyphBuffer.new!()
        |> GlyphBuffer.set_utf8_text!("Hello glyphs")
        |> Font.shape!(font)

      run = GlyphRun.new!(gb)

      canvas
      |> GlyphRun.fill!(
        font,
        100.0,
        120.0,
        run,
        color: Style.color(240, 240, 240)
      )
  """
  @spec fill!(
          Blendend.Canvas.t(),
          Blendend.Text.Font.t(),
          number(),
          number(),
          t(),
          keyword()
        ) :: Blendend.Canvas.t()
  def fill!(canvas, font, x0, y0, glyph_run, opts \\ []) do
    case fill(canvas, font, x0, y0, glyph_run, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:fill_glyph_run, reason)
    end
  end

  @doc """
  Strokes the glyph run on `canvas` using the given `font`.

  The glyphs in `glyph_run` are taken as already shaped for `font`. The run
  is stroked with its origin at `(x0, y0)` in the current canvas transform.

  `opts` is a style keyword list and supports the same options as
  `Blendend.Canvas.Stroke.path/3` (for example `:stroke_color`,
  `:stroke_width`, `:stroke_cap`, `:stroke_line_join`, `:comp_op`, etc.).

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec stroke(
          Blendend.Canvas.t(),
          Blendend.Text.Font.t(),
          number(),
          number(),
          t(),
          keyword()
        ) :: :ok | {:error, term()}
  def stroke(canvas, font, x0, y0, glyph_run, opts \\ []),
    do: Native.stroke_glyph_run(canvas, font, x0 * 1.0, y0 * 1.0, glyph_run, opts)

  @doc """
  Same as `stroke/6`, but returns the canvas and raises on error.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.

  Example, continuing the manual glyph pipeline:

      run = GlyphRun.new!(gb)

      canvas
      |> GlyphRun.stroke!(
        font,
        100.0,
        120.0,
        run,
        stroke_color: Style.color(80, 220, 255),
        stroke_width: 2.0,
        stroke_cap: :round
      )
  """
  @spec stroke!(
          Blendend.Canvas.t(),
          Blendend.Text.Font.t(),
          number(),
          number(),
          t(),
          keyword()
        ) :: Blendend.Canvas.t()
  def stroke!(canvas, font, x0, y0, glyph_run, opts \\ []) do
    case stroke(canvas, font, x0, y0, glyph_run, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:stroke_glyph_run, reason)
    end
  end

  # ===========================================================================
  # Introspection
  # ===========================================================================

  @doc """
  Returns low-level information about a glyph run.

  Map keys (from the NIF) typically include:

    * `:size` – number of glyphs in the run
    * `:placement_type` – numeric `BLGlyphPlacementType`
    * `:glyph_advance` – byte stride between glyph ids
    * `:placement_advance` – byte stride between placements
    * `:flags` – `BLGlyphRunFlags` bitmask
  """
  @spec info(t()) :: {:ok, map()} | {:error, term()}
  def info(run), do: Native.glyph_run_info(run)

  @spec info!(t()) :: map()
  def info!(run) do
    case info(run) do
      {:ok, map} -> map
      {:error, reason} -> raise Error.new(:glyph_run_info, reason)
    end
  end

  @doc """
  Returns a list describing each glyph in the run.

  For runs with placement info, each element is:

      {:glyph, id, {:advance_offset, {ax, ay}, {px, py}}}

  where:

    * `id` – glyph index
    * `{ax, ay}` – pen advance in design units
    * `{px, py}` – placement offset in design units

  Returned as `{:ok, list}` or `{:error, reason}`.
  """
  @spec inspect_run(t()) :: {:ok, list()} | {:error, term()}
  def inspect_run(run), do: Native.glyph_run_inspect(run)

  @spec inspect_run!(t()) :: list()
  def inspect_run!(run) do
    case inspect_run(run) do
      {:ok, list} -> list
      {:error, reason} -> raise Error.new(:glyph_run_inspect, reason)
    end
  end

  @doc """
  Returns a view of the glyph run from `start` (0-based glyph index)
  spanning `count` glyphs. Shares the underlying `GlyphBuffer`.

  On success returns `{:ok, glyph_run}`.
  """
  @spec slice(t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, t()} | {:error, term()}
  def slice(run, start, count),
    do: Native.glyph_run_slice(run, start, count)

  @spec slice!(t(), non_neg_integer(), non_neg_integer()) :: t()
  def slice!(run, start, count) do
    case slice(run, start, count) do
      {:ok, subrun} -> subrun
      {:error, reason} -> raise Error.new(:glyph_run_slice, reason)
    end
  end
end
