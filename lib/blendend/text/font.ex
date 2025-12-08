defmodule Blendend.Text.Font do
  @moduledoc """
  Sized, stateful fonts used by Blendend's text pipeline.

  A `Font` wraps a blend2d `BLFont` instantiated from a `Blendend.Text.Face`
  at a specific size. It exposes the operations needed to:

    * shape `GlyphBuffer`s (kerning, OpenType features, glyph IDs/positions),
    * fetch scaled metrics and text measurement,
    * extract outlines for glyph runs or single glyphs into `Blendend.Path`,
    * read/write OpenType feature settings and the font transform matrix.

  Use this module when you need to turn a loaded face into a drawable font,
  measure shaped text, or emit vector outlines for custom rendering.
  """

  @opaque t :: reference()

  @type feature_tag :: String.t() | atom()
  @type feature_value :: 0..0xFFFF
  @type feature_setting :: {feature_tag(), feature_value()}

  alias Blendend.Native
  alias Blendend.Error
  alias Blendend.Text.{GlyphBuffer, GlyphRun}
  alias Blendend.{Matrix2D, Path}

  @doc """
  Creates a font from a `face` at the given `size`.

  The size is in user units.

  On success, returns `{:ok, font}`.

  On failure, returns `{:error, reason}`.

  ## Examples

      iex> {:ok, face} = Blendend.Text.Face.load("priv/fonts/Alegreya-Regular.otf")
      iex> {:ok, font} = Blendend.Text.Font.create(face, 48.0)
  """
  @spec create(Blendend.Text.Face.t(), number()) :: {:ok, t()} | {:error, term()}
  def create(face, size), do: Native.font_create(face, size * 1.0)

  @doc """
  Same as `create/2`, but returns the font directly.

  On success, returns `font`.

  On failure, raises `Blendend.Error`.
  """
  @spec create!(Blendend.Text.Face.t(), number()) :: t()
  def create!(face, size) do
    case create(face, size) do
      {:ok, font} -> font
      {:error, reason} -> raise Error.new(:font_create, reason)
    end
  end

  # ===========================================================================
  # Metrics
  # ===========================================================================

  @doc """
  Returns scaled metrics for the given `font`.

  On success, returns `{:ok, map}` where `map` includes keys:

    * `"size"`
    * `"ascent"`
    * `"v_ascent"`
    * `"descent"`
    * `"v_descent"`
    * `"line_gap"`
    * `"x_height"`
    * `"cap_height"` 
    * `"x_min"`
    * `"y_min"`
    * `"x_max"`
    * `"y_max"`
    * `"underline_position"`
    * `"underline_thickness"`
    * `"strikethrough_position"`
    * `"strikethrough_thickness"` 

  On failure, returns `{:error, reason}`.
  """
  @spec metrics(t()) :: {:ok, map()} | {:error, term()}
  def metrics(font), do: Native.font_metrics(font)

  @doc """
  Same as `metrics/1`, but returns the metrics map directly.

  On success, returns a map.

  On failure, raises `Blendend.Error`.
  """
  @spec metrics!(t()) :: map()
  def metrics!(font) do
    case metrics(font) do
      {:ok, map} -> map
      {:error, reason} -> raise Error.new(:font_metrics, reason)
    end
  end

  @doc """
  Shapes the contents of a glyph buffer in-place using this `font`.

  This runs blend2d's shaping pipeline on `gb` (glyph indices,
  kerning, OpenType features, etc.).

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec shape(t(), GlyphBuffer.t()) :: :ok | {:error, term()}
  def shape(font, gb), do: Native.font_shape(font, gb)

  @doc """
  Pipeline–friendly version of `shape/2`.

  This variant takes the `GlyphBuffer` first so we can write:

      gb =
        GlyphBuffer.new!()
        |> GlyphBuffer.set_utf8_text!("Hello")
        |> Blendend.Text.Font.shape!(font)

  On success, returns the same `GlyphBuffer`.

  On failure, raises `Blendend.Error`.
  """
  @spec shape!(GlyphBuffer.t(), t()) :: GlyphBuffer.t()
  def shape!(gb, font) do
    case shape(font, gb) do
      :ok -> gb
      {:error, reason} -> raise Error.new(:font_shape, reason)
    end
  end

  @doc """
  Computes text metrics for the shaped contents of a glyph buffer.

  The glyph buffer `gb` must already be shaped with `shape/2` or `shape!/2`.

  On success, returns `{:ok, map}`. The map contains:

    * `"advance_x"` / `"advance_y"` – total pen movement after drawing the run
    * `"bbox_x0"` / `"bbox_y0"` – lower-left corner of the run's tight bounding box
    * `"bbox_x1"` / `"bbox_y1"` – upper-right corner of the run's tight bounding box

  On failure, returns `{:error, reason}`.
  """
  @spec get_text_metrics(t(), GlyphBuffer.t()) :: {:ok, map()} | {:error, term()}
  def get_text_metrics(font, gb),
    do: Native.font_get_text_metrics(font, gb)

  @doc """
  Same as `get_text_metrics/2`, but returns the metrics map directly.

  On success, returns a `map`.

  On failure, raises `Blendend.Error`.
  """
  @spec get_text_metrics!(t(), GlyphBuffer.t()) :: map()
  def get_text_metrics!(font, gb) do
    case get_text_metrics(font, gb) do
      {:ok, map} -> map
      {:error, reason} -> raise Error.new(:font_get_text_metrics, reason)
    end
  end

  @doc """
  Outlines a shaped glyph run into a `Blendend.Path`.

  Given a `glyph_run` (built from a shaped buffer), a transform
  matrix `mtx` and a `path`, this appends the glyph outlines into `path`
  using blend2d's `BLFont::getGlyphRunOutlines`.

  On success, returns `:ok` (with `path` mutated in-place).

  On failure, returns `{:error, reason}`.
  """
  @spec get_glyph_run_outlines(t(), GlyphRun.t(), Matrix2D.t(), Path.t()) ::
          :ok | {:error, term()}
  def get_glyph_run_outlines(font, glyph_run, mtx, path),
    do: Native.font_get_glyph_run_outlines(font, glyph_run, mtx, path)

  @doc """
  Pipeline–friendly version of `get_glyph_run_outlines/4`.

  This variant takes the `Path` first so we can write:

      glyph_path =
        Path.new!()
        |> Blendend.Text.Font.get_glyph_run_outlines!(font, glyph_run, matrix)

  On success, returns the same `Path` (now containing the glyph outlines).

  On failure, raises `Blendend.Error`.
  """
  @spec get_glyph_run_outlines!(Path.t(), t(), GlyphRun.t(), Matrix2D.t()) :: Path.t()
  def get_glyph_run_outlines!(path, font, glyph_run, mtx) do
    case get_glyph_run_outlines(font, glyph_run, mtx, path) do
      :ok -> path
      {:error, reason} -> raise Error.new(:font_get_glyph_run_outlines, reason)
    end
  end

  @type glyph_id :: non_neg_integer()

  @doc """
  Appends the outline of a single `glyph_id` into `path`, transformed by `matrix`.

  This is the "give me one glyph as a path" API:

    * `font`    – a `Blendend.Text.Font.t()`
    * `glyph_id` – shaped glyph index (from a `GlyphRun` or shaper)
    * `matrix`  – a `Blendend.Matrix2D.t()` transform (position/rotation/scale)
    * `path`    – a `Blendend.Path.t()` that will be **cleared** and filled with the outline

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec get_glyph_outlines(t(), glyph_id(), Matrix2D.t(), Path.t()) ::
          :ok | {:error, term()}
  def get_glyph_outlines(font, glyph_id, m, path) do
    Native.font_get_glyph_outlines(font, glyph_id, m, path)
  end

  @doc """
  On success, returns `:ok`.

  On failure, raises `Blendend.Error`.
  """

  @spec get_glyph_outlines!(t(), glyph_id(), Matrix2D.t(), Path.t()) :: :ok
  def get_glyph_outlines!(font, glyph_id, m, path) do
    case get_glyph_outlines(font, glyph_id, m, path) do
      :ok -> :ok
      {:error, reason} -> raise Error.new(:font_get_glyph_outlines, reason)
    end
  end

  @doc """
  Returns the design-space bounding box of `glyph_id` for this `font`.

  For a single glyph id, returns:

      {:ok, {x0, y0, x1, y1}}

  If we pass a list of glyph ids, returns:

      {:ok, [{x0, y0, x1, y1}, ...]}

  All coordinates are in font design units, relative to the glyph origin.
  """
  @spec glyph_bounds(t(), glyph_id() | [glyph_id()]) ::
          {:ok, {number(), number(), number(), number()}}
          | {:ok, [{number(), number(), number(), number()}]}
          | {:error, term()}
  def glyph_bounds(font, glyph_or_list),
    do: Native.font_get_glyph_bounds(font, glyph_or_list)

  @doc """
  Same as `glyph_bounds/2`.

  On success, returns bounding boxes.

  On failure, raises `Blendend.Error`.
  """
  @spec glyph_bounds!(t(), glyph_id() | [glyph_id()]) ::
          {number(), number(), number(), number()}
          | [{number(), number(), number(), number()}]
  def glyph_bounds!(font, glyph_or_list) do
    case glyph_bounds(font, glyph_or_list) do
      {:ok, box_or_boxes} -> box_or_boxes
      {:error, reason} -> raise Error.new(:font_get_glyph_bounds, reason)
    end
  end

  # ===========================================================================
  # Feature settings
  # ===========================================================================

  @doc """
  Creates a font from `face` at `size`, with OpenType feature settings.

  `feats` is a list of `{tag, value}` pairs, where:

    * `tag` – OpenType feature tag (4 characters), as a string or atom,
      e.g. `"liga"`, `"kern"`, `"dlig"`, `"ss01"`.
    * `value` – integer in `0..65535`, most commonly `0` (off) or `1` (on).

  On success, returns `{:ok, font}`.

  On failure, returns `{:error, reason}`.
  """
  @spec create_with_features(Blendend.Text.Face.t(), number(), [feature_setting()]) ::
          {:ok, t()} | {:error, term()}
  def create_with_features(face, size, feats),
    do: Native.font_create_with_features(face, size, feats)

  @doc """
  Same as `create_with_features/3`, but returns the font directly.

  On success, returns `font`.

  On failure, raises `Blendend.Error`.
  """
  @spec create_with_features!(Blendend.Text.Face.t(), number(), [feature_setting()]) :: t()
  def create_with_features!(face, size, feats) do
    case create_with_features(face, size, feats) do
      {:ok, font} -> font
      {:error, reason} -> raise Error.new(:font_create_with_features, reason)
    end
  end

  @doc """
  Returns the current OpenType feature settings of this `font`.

  On success, returns `{:ok, feats}` where `feats` is a list of
  `{tag, value}` pairs, mirroring `create_with_features/3`.

  On failure, returns `{:error, reason}`.
  """
  @spec get_feature_settings(t()) :: {:ok, [feature_setting()]} | {:error, term()}
  def get_feature_settings(font),
    do: Native.font_get_feature_settings(font)

  @doc """
  Same as `get_feature_settings/1`, but returns the list directly.

  On success, returns the list of `{tag, value}` pairs.

  On failure, raises `Blendend.Error`.
  """
  @spec get_feature_settings!(t()) :: [feature_setting()]
  def get_feature_settings!(font) do
    case get_feature_settings(font) do
      {:ok, feats} -> feats
      {:error, reason} -> raise Error.new(:font_get_feature_settings, reason)
    end
  end

  @doc """
  Returns the font's transformation matrix.

  On success, returns `{:ok, map}` where `map` contains:

    * `"m00"` – horizontal scale
    * `"m11"` – vertical scale
    * `"m01"` – x-shear
    * `"m10"` – y-shear

  These describe how the font's internal design units are mapped into
  user-space.

  It’s the transform from font design space -> user/canvas space:

   x_px = m00 * x_design + m01 * y_design
   y_px = m10 * x_design + m11 * y_design

  Example: if the face has 1000 units-per-em and the font was created
  at size 42, then:

      m00 = 42 / 1000 = 0.042

  so a horizontal advance of `534.0` design units becomes
  `534 * 0.042 = 22.4` pixels on screen.

  "m01" = 0.0, "m10" = 0.0 – shear components
    Both zero -> no skew. If they were non-zero,
    we'd have some kind of slant / skew applied in the font matrix.

  On failure, returns `{:error, reason}`.
  """
  @spec matrix(t()) :: {:ok, map()} | {:error, term()}
  def matrix(font), do: Native.font_get_matrix(font)

  @doc """
  Same as `matrix/1`, but returns the matrix map directly.

  On success, returns `map`.

  On failure, raises `Blendend.Error`.

  ## Examples

      iex> face = Blendend.Text.Face.load!("priv/fonts/ABeeZee-Regular.ttf")
      iex> font = Blendend.Text.Font.create!(face, 42.0)
      iex> Blendend.Text.Font.matrix!(font)
      %{"m00" => sx, "m01" => 0.0, "m10" => 0.0, "m11" => sy}
  """
  @spec matrix!(t()) :: map()
  def matrix!(font) do
    case matrix(font) do
      {:ok, m} -> m
      {:error, reason} -> raise Error.new(:font_get_matrix, reason)
    end
  end
end
