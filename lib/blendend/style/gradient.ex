defmodule Blendend.Style.Gradient do
  @moduledoc """
  Gradient style helpers for Blendend.

  This module works with **gradient** values that can be
  used as fill or stroke styles in `Blendend.Canvas` / `Blendend.Draw`
  functions.

  This module is used in three steps:

    1. Create a gradient with one of:

        * `linear/4`  – linear gradient between two points
        * `radial/6`  – radial gradient with center, radius and focal point
        * `conic/3`   – conic (angular) gradient around a center

    2. Add color stops using `add_stop/3` (or `add_stop!/3`).

    3. (Optionally) configure how the gradient behaves:

        * `set_extend/2` / `set_extend!/2`       – choose how the gradient
          extends outside its 0.0–1.0 range (`:pad`, `:repeat`, `:reflect`).

        * `set_transform/2` / `set_transform!/2` – apply a `Blendend.Matrix2D`
          transform that controls how the gradient is positioned, rotated or
          scaled in canvas coordinates.

        * `reset_transform/1` / `reset_transform!/1` – clear any transform
          back to identity.

  Gradients created here are typically passed as the `:gradient` or
  `:stroke_gradient` option to drawing functions such as
  `Blendend.Canvas.Fill.rect/6`
  `Blendend.Canvas.Stroke.circle/5`.
  """

  alias Blendend.Native
  alias Blendend.Error

  @opaque t :: reference()
  @type extend_mode :: :pad | :repeat | :reflect

  # ---------------------------------------------------------------------------
  # Constructors
  # ---------------------------------------------------------------------------

  @doc """
  Creates a linear gradient between two points.

  The gradient line goes from `(x0, y0)` to `(x1, y1)`.

  On success, returns `{:ok, gradient}` where `gradient` is a gradient
  resource.

  On failure, returns `{:error, reason}`.

  Use `add_stop/3` to populate the gradient with one or more
  color stops, then pass the gradient as `gradient:` or `stroke_gradient:`
  in drawing options.

  Offsets given to `add_stop/3` are typically in the range
  `0.0..1.0` (start to end).

  ## Examples

      iex> {:ok, grad} = Blendend.Style.Gradient.linear(0.0, 0.0, 0.0, 200.0)
      iex> :ok = Blendend.Style.Gradient.add_stop(grad, 0.0, Blendend.Style.Color.rgb!(255, 0, 0))
      iex> :ok = Blendend.Style.Gradient.add_stop(grad, 1.0, Blendend.Style.Color.rgb!(0, 0, 255))
      iex> rect 0, 0, 200, 200, gradient: grad
  """
  @spec linear(number(), number(), number(), number()) ::
          {:ok, t()} | {:error, term()}
  def linear(x0, y0, x1, y1),
    do: Native.gradient_linear(x0 * 1.0, y0 * 1.0, x1 * 1.0, y1 * 1.0)

  @doc """
  Same as `linear/4`, but on success, returns the `gradient`.

  On failure, raises `Blendend.Error`.
  """
  @spec linear!(number(), number(), number(), number()) :: t()
  def linear!(x0, y0, x1, y1) do
    case linear(x0, y0, x1, y1) do
      {:ok, grad} -> grad
      {:error, reason} -> raise Error.new(:gradient_linear, reason)
    end
  end

  @doc """
  Creates a radial gradient.

  The gradient is defined by:

    * `cx0`, `cy0`, `r0` – inner circle center and radius
    * `cx1`, `cy1`, `r1` – outer circle center and radius

  On success, returns `{:ok, gradient}`.

  On failure, returns `{:error, reason}`.
  """
  @spec radial(number(), number(), number(), number(), number(), number()) ::
          {:ok, t()} | {:error, term()}
  def radial(cx0, cy0, r0, cx1, cy1, r1),
    do: Native.gradient_radial(cx0 * 1.0, cy0 * 1.0, cx1 * 1.0, cy1 * 1.0, r0 * 1.0, r1 * 1.0)

  @doc """
  Same as `radial/6`, but returns the gradient directly.

  On success, returns `gradient`.

  On failure, raises `Blendend.Error`.
  """
  @spec radial!(number(), number(), number(), number(), number(), number()) :: t()
  def radial!(cx0, cy0, r0, cx1, cy1, r1) do
    case radial(cx0, cy0, r0, cx1, cy1, r1) do
      {:ok, grad} -> grad
      {:error, reason} -> raise Error.new(:gradient_radial, reason)
    end
  end

  @doc """
  Creates a conic (angular) gradient.

  The gradient is defined by:

    * `cx`, `cy` – center of rotation
    * `angle`    – starting angle in radians

  On success, returns `{:ok, gradient}`.

  On failure, returns `{:error, reason}`.
  """
  @spec conic(number(), number(), number()) ::
          {:ok, t()} | {:error, term()}
  def conic(cx, cy, angle),
    do: Native.gradient_conic(cx * 1.0, cy * 1.0, angle * 1.0)

  @doc """
  Same as `conic/3`, but returns the gradient directly.

  On success, returns `gradient`.

  On failure, raises `Blendend.Error`.
  """
  @spec conic!(number(), number(), number()) :: t()
  def conic!(cx, cy, angle) do
    case conic(cx, cy, angle) do
      {:ok, grad} -> grad
      {:error, reason} -> raise Error.new(:gradient_conic, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Stops
  # ---------------------------------------------------------------------------

  @doc """
  Adds a color stop to a gradient.

  * `grad`   – a gradient resource
  * `offset` – a numeric position along the gradient (usually `0.0..1.0`)
  * `color`  – a color resource created with `Blendend.Style.Color.rgb/3` or `/4`

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec add_stop(t(), float(), term()) :: :ok | {:error, term()}
  def add_stop(grad, offset, color),
    do: Native.gradient_add_stop(grad, offset * 1.0, color)

  @doc """
  Same as `add_stop/3`, but returns the gradient directly.

  On success, returns `gradient`.

  On failure, raises `Blendend.Error`.
  """
  @spec add_stop!(t(), float(), term()) :: t()
  def add_stop!(grad, offset, color) do
    case add_stop(grad, offset, color) do
      :ok -> grad
      {:error, reason} -> raise Error.new(:gradient_add_stop, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Extend
  # ---------------------------------------------------------------------------

  @doc """
  Sets the extend mode of a gradient.

  The extend mode controls how the gradient behaves outside the range
  covered by its stops (typically offsets `0.0..1.0`). Supported modes:

    * `:pad`     – clamp to the edge colors (default)
    * `:repeat`  – repeat the gradient pattern
    * `:reflect` – repeat the gradient, flipping direction every cycle

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec set_extend(t(), extend_mode()) :: :ok | {:error, term()}
  def set_extend(grad, mode)
      when mode in [:pad, :repeat, :reflect] do
    Native.gradient_set_extend(grad, mode)
  end

  @doc """
  Same as `set_extend/2`, but returns the gradient directly.

  On success, returns `gradient`.

  On failure, raises `Blendend.Error`.
  """
  @spec set_extend!(t(), extend_mode()) :: t()
  def set_extend!(grad, mode) do
    case set_extend(grad, mode) do
      :ok -> grad
      {:error, reason} -> raise Error.new(:gradient_set_extend, reason)
    end
  end

  # ---------------------------------------------------------------------------
  # Transforms
  # ---------------------------------------------------------------------------

  @doc """
  Sets the transform matrix used when sampling a gradient.

  The matrix is expressed in canvas coordinates and controls how the
  gradient is positioned, rotated, or scaled relative to the canvas.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec set_transform(t(), Blendend.Matrix2D.t()) :: :ok | {:error, term()}
  def set_transform(gradient, matrix),
    do: Native.gradient_set_transform(gradient, matrix)

  @doc """
  Same as `set_transform/2`, but returns the gradient directly.

  On success, returns `gradient`.

  On failure, raises `Blendend.Error`.
  """
  @spec set_transform!(t(), Blendend.Matrix2D.t()) :: t()
  def set_transform!(grad, matrix) do
    case set_transform(grad, matrix) do
      :ok -> grad
      {:error, reason} -> raise Error.new(:gradient_set_transform, reason)
    end
  end

  @doc """
  Resets a gradient’s transform to the identity matrix.

  After calling this function, the gradient is mapped directly in canvas
  coordinates using the positions it was created with, without any extra
  rotation / scaling / translation.

  On success, returns `:ok`.

  On failure, returns `{:error, reason}`.
  """
  @spec reset_transform(t()) :: :ok | {:error, term()}
  def reset_transform(gradient),
    do: Native.gradient_reset_transform(gradient)

  @doc """
  Same as `reset_transform/1`, but returns the gradient directly.

  On success, returns `gradient`.

  On failure, raises `Blendend.Error`.
  """
  @spec reset_transform!(t()) :: t()
  def reset_transform!(grad) do
    case reset_transform(grad) do
      :ok -> grad
      {:error, reason} -> raise Error.new(:gradient_reset_transform, reason)
    end
  end

  @spec with_stops(t(), [{float(), Color.t()}]) :: t()
  defp with_stops(gradient, stops) do
    Enum.reduce(stops, gradient, fn {t, color}, grad ->
      add_stop!(grad, t, color)
    end)
  end

  @doc """
  Creates a linear gradient for the given line and adds `stops` in one go.

  * `line` – `{x0, y0, x1, y1}`
  * `stops` – list of `{offset, color}` where `offset is 0.0..1.0`

  Options:

    * `:extend` – `:pad | :repeat | :reflect` (default: `:pad`)

  Returns a gradient resource suitable for use as fill or stroke.
  """
  @spec linear_from_stops(
          {number(), number(), number(), number()},
          [{float(), Blended.Style.Color.t()}],
          keyword()
        ) :: t()
  def linear_from_stops({x0, y0, x1, y1}, stops, opts \\ []) do
    grad =
      linear!(x0, y0, x1, y1)
      |> set_extend!(Keyword.get(opts, :extend, :pad))
      |> with_stops(stops)

    grad
  end

  @doc """
  Creates a radial gradient and adds `stops`.

  * `cx0`, `cy0`, `r0` – inner circle center and radius
  * `cx1`, `cy1`, `r1` – outer circle center and radius
  * `stops` – list of `{offset, color}`

  Options:

    * `:extend` – extend mode (`:pad | :repeat | :reflect`), defaults to `:pad`.
  """
  @spec radial_from_stops(
          {number(), number(), number(), number(), number(), number()},
          [{float(), Blended.Style.Color.t()}],
          keyword()
        ) :: t()
  def radial_from_stops({cx0, cy0, r0, cx1, cy1, r1}, stops, opts \\ []) do
    radial!(cx0, cy0, r0, cx1, cy1, r1)
    |> set_extend!(Keyword.get(opts, :extend, :pad))
    |> with_stops(stops)
  end

  @doc """
  Creates a conic gradient and adds `stops`.

  * `{cx, cy, angle}` – center and angle in radians
  * `stops` – list of `{offset, color}`

  Options:

    * `:extend` – extend mode (`:pad | :repeat | :reflect`), defaults to `:pad`.
  """
  @spec conic_from_stops(
          {number(), number(), number()},
          [{float(), Blended.Style.Color.t()}],
          keyword()
        ) :: t()
  def conic_from_stops({cx, cy, angle}, stops, opts \\ []) do
    conic!(cx, cy, angle)
    |> set_extend!(Keyword.get(opts, :extend, :pad))
    |> with_stops(stops)
  end
end
