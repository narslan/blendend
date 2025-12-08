defmodule Blendend.Canvas do
  @moduledoc """
  Drawing surface of `blend2d`.

  A `Blendend.Canvas` represents a 2D drawing surface backed by a `blend2d`
  `BLImage` and `BLContext`. Most functions here delegate to the internal NIF
  module (not part of the public API) while accepting plain Elixir numbers and
  option lists.
  while accepting plain Elixir numbers and option lists.

  All transformation functions in this module mutate the canvas' internal
  **user transform** in-place. 

  Under the hood, the backing image is created as a `blend2d` `BLImage` with
  format `BL_FORMAT_PRGB32` (premultiplied 32-bit RGBA).
  """

  @typedoc "Canvas/context resource backed by a blend2d `BLContext`."
  @opaque t :: reference()

  alias Blendend.{Native, Error, Matrix2D, Image}

  # ===========================================================================
  # Construction
  # ===========================================================================

  @doc """
  Creates a new canvas of size `width × height` pixels.

  The dimensions are given in device pixels and must be positive integers.

  Returns `{:ok, canvas}` on success, where `canvas` is a reference that
  you pass to the other functions in this module.

  """
  @spec new(pos_integer(), pos_integer()) :: {:ok, t()} | {:error, term()}
  def new(w, h), do: Native.canvas_new(w, h)

  @doc """
  Same as `new/2`, but returns the canvas directly.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec new!(pos_integer(), pos_integer()) :: t()
  def new!(w, h) do
    case new(w, h) do
      {:ok, canvas} -> canvas
      {:error, reason} -> raise Error.new(:canvas_new, reason)
    end
  end

  @doc """
  Saves the contents of a canvas to a png image file on disk.

  The `path` is a filename (e.g. `"out.png"`). 

  Returns `:ok` on success or `{:error, reason}` if the image could not be
  written.

  ## Examples

      iex> {:ok, c} = Blendend.Canvas.new(100, 100)
      iex> :ok = Blendend.Canvas.clear(c)
      iex> :ok = Blendend.Canvas.save(c, "test_output.png")
  """
  @spec save(t(), String.t()) :: :ok | {:error, term()}
  def save(canvas, path) do
    with {:ok, bin} <- to_png(canvas),
         :ok <- File.write(path, bin) do
      :ok
    end
  end

  @doc """
  Same as `save/2`, but raises on failure.

  On success, returns `:ok`.

  On failure, raises `Blendend.Error`.
  """
  @spec save!(t(), String.t()) :: :ok
  def save!(canvas, path) do
    case save(canvas, path) do
      :ok ->
        :ok

      {:error, reason} ->
        raise Error.new(:canvas_save, reason)

      other ->
        # if to_png ever returns some weird shape, still blow up loudly
        raise Error.new(:canvas_save, other)
    end
  end

  @doc """
  Saves the contents of a canvas to an image file on disk in QOI format.

  The `path` is a filename (e.g. `"out.qoi"`). 

  Returns `:ok` on success or `{:error, reason}` if writing fails.

  ## Examples

      iex> {:ok, c} = Blendend.Canvas.new(100, 100)
      iex> :ok = Blendend.Canvas.clear(c)
      iex> :ok = Blendend.Canvas.save_qoi(c, "test_output.qoi")
  """
  @spec save_qoi(t(), String.t()) :: :ok | {:error, term()}
  def save_qoi(canvas, path) do
    with {:ok, bin} <- to_qoi(canvas),
         :ok <- File.write(path, bin) do
      :ok
    end
  end

  @doc """
  Same as `save_qoi/2`, but raises on failure.

  On success, returns `:ok`.

  On failure, raises `Blendend.Error`.
  """
  @spec save_qoi!(t(), String.t()) :: :ok
  def save_qoi!(canvas, path) do
    case save_qoi(canvas, path) do
      :ok ->
        :ok

      {:error, reason} ->
        raise Error.new(:canvas_save_qoi, reason)

      other ->
        raise Error.new(:canvas_save_qoi, other)
    end
  end

  @doc """
  Clears the entire canvas.

  Without options, the canvas is cleared to whatever `blend2d` considers the
  default (transparent black).

  With options, the call behaves like a full–canvas fill using the given
  style (for example a solid background color):

      iex> c = Blendend.Canvas.new!(100, 100)
      iex> :ok = Blendend.Canvas.clear(c, color: Blendend.Style.Color.rgb!(255, 255, 255))

  The exact shape of the options is the same as the shape–drawing functions in
  `Blendend.Canvas.Fill.path/3`.
  """
  @spec clear(t(), keyword()) :: :ok | {:error, term()}
  def clear(canvas, opts \\ []), do: Native.canvas_clear(canvas, opts)

  @doc """
  Same as `clear/2`, but returns the `canvas` on success.

  On failure, raises `Blendend.Error`.
  """
  @spec clear!(t(), keyword()) :: t()
  def clear!(canvas, opts \\ []) do
    case clear(canvas, opts) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_clear, reason)
    end
  end

  @doc """
  Stores the current rendering context state on an internal stack.

  This captures:

    * current transform,
    * clip,
    * stroke/fill styles,
    * and other `blend2d` context state.

  You can later restore it with `restore_state/1`.
  """
  @spec save_state(t()) :: :ok | {:error, term()}
  def save_state(canvas), do: Native.canvas_save_state(canvas)

  @doc """
  Same as `save_state/1`, but returns the canvas.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec save_state!(t()) :: t()
  def save_state!(canvas) do
    case save_state(canvas) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_save_state, reason)
    end
  end

  @doc """
  Restores the most recently saved context state.

  This pops from the internal state stack created by `save_state/1`.

  Returns `:ok` on success, or `{:error, reason}` if there is no state
  to restore or the context is invalid.
  """
  @spec restore_state(t()) :: :ok | {:error, term()}
  def restore_state(canvas), do: Native.canvas_restore_state(canvas)

  @doc """
  Same as `restore_state/1`, but returns the canvas.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec restore_state!(t()) :: t()
  def restore_state!(canvas) do
    case restore_state(canvas) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_restore_state, reason)
    end
  end

  @doc """
  Sets the user transformation matrix to `matrix`.

  This replaces the current user transform.
  """
  @spec set_transform(t(), Matrix2D.t()) :: :ok | {:error, term()}
  def set_transform(canvas, matrix), do: Native.canvas_set_transform(canvas, matrix)

  @doc """
  Same as `set_transform/2`, but returns the canvas.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec set_transform!(t(), Matrix2D.t()) :: t()
  def set_transform!(canvas, matrix) do
    case set_transform(canvas, matrix) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_set_transform, reason)
    end
  end

  @doc """
  Resets the user transformation matrix to identity.
  """
  @spec reset_transform(t()) :: :ok | {:error, term()}
  def reset_transform(canvas), do: Native.canvas_reset_transform(canvas)

  @doc """
  Same as `reset_transform/1`, but returns the canvas.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec reset_transform!(t()) :: t()
  def reset_transform!(canvas) do
    case reset_transform(canvas) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_reset_transform, reason)
    end
  end

  @doc """
  Translates the canvas' user transform by `(tx, ty)` in user coordinates.
  M = T(x, y) · M (apply translation in user space before the current transform).
  This mutates the canvas in-place.

  ## Examples

      {:ok, c} = Canvas.new(600, 400)
      :ok = Canvas.translate(c, 10, 5)
      # all shapes drawn afterwards are offset by (10, 5)
  """
  @spec translate(t(), number(), number()) :: :ok | {:error, term()}
  def translate(canvas, tx, ty),
    do: Native.canvas_translate(canvas, tx * 1.0, ty * 1.0)

  @doc """
  Same as `translate/3`, but returns the canvas.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec translate!(t(), number(), number()) :: t()
  def translate!(canvas, x, y) do
    case translate(canvas, x, y) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_translate, reason)
    end
  end

  @doc """
  Applies a translation after the current transform (post-translate).

  M = M · T(x, y) (apply translation in the already-transformed/user space).
  """
  @spec post_translate(t(), number(), number()) :: :ok | {:error, term()}
  def post_translate(canvas, tx, ty),
    do: Native.canvas_post_translate(canvas, tx * 1.0, ty * 1.0)

  @doc """
  Same as `post_translate/3`, but returns the canvas and raises on error.
  """
  @spec post_translate!(t(), number(), number()) :: t()
  def post_translate!(canvas, x, y) do
    case post_translate(canvas, x, y) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_post_translate, reason)
    end
  end

  @doc """
  Scales the canvas' user transform by `sx` (x-axis) and `sy` (y-axis).

  This mutates the canvas in-place.

  ## Examples

      {:ok, c} = Canvas.new(600, 400)
      :ok = Canvas.scale(c, 2, 3)
      # subsequent drawing is stretched (2x horizontally, 3x vertically)
  """
  @spec scale(t(), number(), number()) :: :ok | {:error, term()}
  def scale(canvas, sx, sy),
    do: Native.canvas_scale(canvas, sx * 1.0, sy * 1.0)

  @doc """
  Same as `scale/3`, but returns the canvas.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec scale!(t(), number(), number()) :: t()
  def scale!(canvas, sx, sy) do
    case scale(canvas, sx, sy) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_scale, reason)
    end
  end

  @doc """
  Rotates the canvas' user transform by `angle` radians.

  The rotation is around the origin `(0, 0)` of the canvas coordinate
  system. This mutates the canvas in-place.
  """
  @spec rotate(t(), number()) :: :ok | {:error, term()}
  def rotate(canvas, angle_radians),
    do: Native.canvas_rotate(canvas, angle_radians * 1.0)

  @doc """
  Rotates the canvas' user transform by `angle` radians around the point `{cx, cy}`.

  Mutates the canvas in-place.
  """
  @spec rotate_at(t(), number(), number(), number()) :: :ok | {:error, term()}
  def rotate_at(canvas, angle_radians, cx, cy),
    do: Native.canvas_rotate_at(canvas, angle_radians * 1.0, cx * 1.0, cy * 1.0)

  @doc """
  Post-multiplies the canvas transform by a rotation of `angle` radians.
  """
  @spec post_rotate(t(), number()) :: :ok | {:error, term()}
  def post_rotate(canvas, angle_radians),
    do: Native.canvas_post_rotate(canvas, angle_radians * 1.0)

  @doc """
  Post-multiplies the canvas transform by a rotation of `angle` radians around `{cx, cy}`.
  """
  @spec post_rotate_at(t(), number(), number(), number()) :: :ok | {:error, term()}
  def post_rotate_at(canvas, angle_radians, cx, cy),
    do: Native.canvas_post_rotate_at(canvas, angle_radians * 1.0, cx * 1.0, cy * 1.0)

  @doc """
  Same as `rotate/2`, but returns the canvas.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec rotate!(t(), number()) :: t()
  def rotate!(canvas, angle) do
    case rotate(canvas, angle) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_rotate, reason)
    end
  end

  @doc """
  Same as `rotate_at/4`, but returns the canvas or raises on error.
  """
  @spec rotate_at!(t(), number(), number(), number()) :: t()
  def rotate_at!(canvas, angle, cx, cy) do
    case rotate_at(canvas, angle, cx, cy) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_rotate_at, reason)
    end
  end

  @doc """
  Same as `post_rotate/2`, but returns the canvas or raises on error.
  """
  @spec post_rotate!(t(), number()) :: t()
  def post_rotate!(canvas, angle) do
    case post_rotate(canvas, angle) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_post_rotate, reason)
    end
  end

  @doc """
  Same as `post_rotate_at/4`, but returns the canvas or raises on error.
  """
  @spec post_rotate_at!(t(), number(), number(), number()) :: t()
  def post_rotate_at!(canvas, angle, cx, cy) do
    case post_rotate_at(canvas, angle, cx, cy) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_post_rotate_at, reason)
    end
  end

  @doc """
  Skews (shears) the canvas' user transform by `kx` and `ky` radians along the
  X and Y axes.

  This mutates the canvas in-place.
  """
  @spec skew(t(), number(), number()) :: :ok | {:error, term()}
  def skew(canvas, kx, ky),
    do: Native.canvas_skew(canvas, kx * 1.0, ky * 1.0)

  @doc """
  Same as `skew/3`, but returns the canvas.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec skew!(t(), number(), number()) :: t()
  def skew!(canvas, kx, ky) do
    case skew(canvas, kx, ky) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_skew, reason)
    end
  end

  @doc """
  Blits an image onto the canvas at the given coordinates.

  This copies the pixels of `image` so its top-left lands on `{x, y}` without
  scaling or tiling, using Blend2D's `blit_image/2`.
  """
  @spec blit_image(t(), Image.t(), number(), number()) :: :ok | {:error, term()}
  def blit_image(canvas, image, x, y),
    do: Native.canvas_blit_image(canvas, image, x * 1.0, y * 1.0)

  @doc """
  Same as `blit_image/4`, but raises on failure and returns the canvas.
  """
  @spec blit_image!(t(), Image.t(), number(), number()) :: t()
  def blit_image!(canvas, image, x, y) do
    case blit_image(canvas, image, x, y) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_blit_image, reason)
    end
  end

  @doc """
  Blits an image scaled to the rectangle `{x, y, w, h}`.

  The image is resampled to fit the destination rectangle using
  Blend2D's `blit_image/3` overload (no source sub-rect applied).
  """
  @spec blit_image(t(), Image.t(), number(), number(), number(), number()) ::
          :ok | {:error, term()}
  def blit_image(canvas, image, x, y, w, h),
    do: Native.canvas_blit_image_scaled(canvas, image, x * 1.0, y * 1.0, w * 1.0, h * 1.0)

  @doc """
  Same as `blit_image/6`, but raises on failure and returns the canvas.
  """
  @spec blit_image!(t(), Image.t(), number(), number(), number(), number()) :: t()
  def blit_image!(canvas, image, x, y, w, h) do
    case blit_image(canvas, image, x, y, w, h) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_blit_image_scaled, reason)
    end
  end

  # ===========================================================================
  # Export: PNG / Base64 / QOI
  # ===========================================================================

  @doc """
  Encodes the current canvas contents as PNG.

  On success, returns `{:ok, binary}` where `binary` is a valid PNG stream.

  On failure, returns `{:error, reason}`.
  """
  @spec to_png(t()) :: {:ok, binary()} | {:error, term()}
  def to_png(canvas), do: Native.canvas_to_png(canvas)

  @doc """
  Same as `to_png/1`, but returns the PNG binary directly.

  On success, returns the PNG `binary`.

  On failure, raises `Blendend.Error`.
  """
  @spec to_png!(t()) :: binary()
  def to_png!(canvas) do
    case to_png(canvas) do
      {:ok, bin} -> bin
      {:error, reason} -> raise Error.new(:canvas_to_png, reason)
    end
  end

  @doc """
  Encodes the canvas as PNG and returns a Base64–encoded string.

  On success, returns `{:ok, base64}` where `base64` is the PNG encoded as a
  Base64 binary (no data URL prefix is added).

  On failure, returns `{:error, reason}`.
  """
  @spec to_png_base64(t()) :: {:ok, binary()} | {:error, term()}
  def to_png_base64(canvas), do: Native.canvas_to_png_base64(canvas)

  @doc """
  Same as `to_png_base64/1`, but returns the Base64 string directly.

  On success, returns the Base64-encoded PNG `binary`.

  On failure, raises `Blendend.Error`.
  """
  @spec to_png_base64!(t()) :: binary()
  def to_png_base64!(canvas) do
    case to_png_base64(canvas) do
      {:ok, bin} -> bin
      {:error, reason} -> raise Error.new(:canvas_to_png_base64, reason)
    end
  end

  @doc """
  Encodes the canvas as a QOI image and returns the raw `.qoi` binary.

  On success returns `{:ok, binary}` where `binary` is the file contents you
  could write directly to `"something.qoi"`.

  Note: browsers don’t natively understand QOI, so this is mainly useful for
  offline assets, tests/benchmarks, or feeding into your own decoder.
  """
  @spec to_qoi(t()) :: {:ok, binary()} | {:error, term()}
  def to_qoi(canvas), do: Native.canvas_to_qoi(canvas)

  @doc """
  Same as `to_qoi/1`, but returns the QOI binary directly.

  On success, returns the QOI `binary`.

  On failure, raises `Blendend.Error`.
  """
  @spec to_qoi!(t()) :: binary()
  def to_qoi!(canvas) do
    case to_qoi(canvas) do
      {:ok, bin} -> bin
      {:error, reason} -> raise Error.new(:canvas_to_qoi, reason)
    end
  end

  # ===========================================================================
  # Matrix helpers
  # ===========================================================================

  @doc """
  Applies the given matrix to the canvas' user transform.

  This composes the current transform with the provided `Blendend.Matrix2D.t()`,
  using blend2d's `BLContext::applyTransform`. The canvas is mutated in-place.
  """
  @spec apply_transform(t(), Matrix2D.t()) :: :ok | {:error, term()}
  def apply_transform(canvas, matrix),
    do: Native.canvas_apply_transform(canvas, matrix)

  @doc """
  Same as `apply_transform/2`, but returns the canvas.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec apply_transform!(t(), Matrix2D.t()) :: t()
  def apply_transform!(canvas, matrix) do
    case apply_transform(canvas, matrix) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_apply_transform, reason)
    end
  end

  @doc """
  Returns a snapshot of the canvas' current user transform.

  On success, returns `{:ok, matrix}` where `matrix` is a
  `Blendend.Matrix2D.t()`.

  On failure, returns `{:error, reason}`.
  """
  @spec user_transform(t()) :: {:ok, Matrix2D.t()} | {:error, term()}
  def user_transform(canvas),
    do: Native.canvas_user_transform(canvas)

  @doc """
  Same as `user_transform/1`, but returns the matrix directly.

  On success, returns a `Blendend.Matrix2D.t()`.

  On failure, raises `Blendend.Error`.
  """
  @spec user_transform!(t()) :: Matrix2D.t()
  def user_transform!(canvas) do
    case user_transform(canvas) do
      {:ok, m} -> m
      {:error, reason} -> raise Error.new(:canvas_user_transform, reason)
    end
  end

  # ===========================================================================
  # Fill rule
  # ===========================================================================

  @doc """
  Sets the fill rule for subsequent fill operations on the canvas.

  Supported rules:

    * `:non_zero` / `:nonzero` – non–zero winding rule
    * `:even_odd` / `:evenodd` – even/odd rule

  Returns `:ok` on success, or `{:error, reason}` if the rule is invalid.
  """
  @spec set_fill_rule(t(), :non_zero | :even_odd) :: :ok | {:error, term()}
  def set_fill_rule(canvas, rule),
    do: Native.canvas_set_fill_rule(canvas, rule)

  @doc """
  Same as `set_fill_rule/2`, but returns the canvas.

  On success, returns `canvas`.

  On failure, raises `Blendend.Error`.
  """
  @spec set_fill_rule!(t(), :non_zero | :even_odd) :: t()
  def set_fill_rule!(canvas, rule) do
    case set_fill_rule(canvas, rule) do
      :ok -> canvas
      {:error, reason} -> raise Error.new(:canvas_set_fill_rule, reason)
    end
  end
end
