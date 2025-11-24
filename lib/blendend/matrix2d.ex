defmodule Blendend.Matrix2D do
  @moduledoc """
  Thin wrapper around blend2d's `BLMatrix2D`.

  Internally this is a NIF resource representing an affine transform:

      | m00  m01  tx |
      | m10  m11  ty |
      |  0    0   1  |

  Most functions in this module either create such a matrix or
  compose/inspect it.

  * `m00, m01, m10, m11` – linear part (scale, rotation, skew)
  * `tx, ty`             – translation
  """

  @opaque t :: reference()

  alias Blendend.Native
  alias Blendend.Error

  # ===========================================================================
  # Constructors
  # ===========================================================================

  @doc """
  Creates a matrix from a 6-element list `[m00, m01, m10, m11, tx, ty]`.

  On success, returns `{:ok, matrix}` where `matrix` is a `Blendend.Matrix2D.t()`.

  On failure, returns `{:error, reason}`.
  """
  @spec new([number()]) :: {:ok, t()} | {:error, term()}
  def new(lst), do: Native.matrix2d_new(lst)

  @doc """
  Same as `new/1`, but returns the matrix directly.

  On success, returns `matrix`.

  On failure, raises `Blendend.Error`.
  """
  @spec new!([number()]) :: t()
  def new!(lst) do
    case new(lst) do
      {:ok, m} -> m
      {:error, reason} -> raise Error.new(:matrix2d_new, reason)
    end
  end

  @doc """
  Returns the identity transform matrix.

  On success, returns `{:ok, matrix}`.

  On failure, returns `{:error, reason}`.
  """
  @spec identity() :: {:ok, t()} | {:error, term()}
  def identity, do: Native.matrix2d_identity()

  @doc """
  Same as `identity/0`, but returns the matrix directly.

  On success, returns `matrix`.

  On failure, raises `Blendend.Error`.
  """
  @spec identity!() :: t()
  def identity! do
    case identity() do
      {:ok, m} -> m
      {:error, reason} -> raise Error.new(:matrix2d_identity, reason)
    end
  end

  # ===========================================================================
  # Conversion
  # ===========================================================================

  @doc """
  Reads the matrix as `[m00, m01, m10, m11, tx, ty]`.

  On success, returns `{:ok, list}`.

  On failure, returns `{:error, reason}`.
  """
  @spec to_list(t()) :: {:ok, [number()]} | {:error, term()}
  def to_list(m), do: Native.matrix2d_to_list(m)

  @doc """
  Same as `to_list/1`, but returns the list directly.

  On success, returns `[m00, m01, m10, m11, tx, ty]`.

  On failure, raises `Blendend.Error`.
  """
  @spec to_list!(t()) :: [number()]
  def to_list!(m) do
    case to_list(m) do
      {:ok, list} -> list
      {:error, reason} -> raise Error.new(:matrix2d_to_list, reason)
    end
  end

  # ===========================================================================
  # Operations
  # ===========================================================================

  @doc """
  Composes (multiplies) two matrices and returns a **new** matrix.

  `compose(a, b)` returns `{:ok, c}` where `c = b * a`.

  On failure, returns `{:error, reason}`.
  """
  @spec compose(t(), t()) :: {:ok, t()} | {:error, term()}
  def compose(a, b), do: Native.matrix2d_compose(a, b)

  @doc """
  Same as `compose/2`, but returns the composed matrix directly.

  On success, returns `matrix`.

  On failure, raises `Blendend.Error`.
  """
  @spec compose!(t(), t()) :: t()
  def compose!(a, b) do
    case compose(a, b) do
      {:ok, m} -> m
      {:error, reason} -> raise Error.new(:matrix2d_compose, reason)
    end
  end

  @doc """
  Translates the matrix by `{tx, ty}` and returns a new matrix.

  On success, returns `{:ok, matrix}`.

  On failure, returns `{:error, reason}`.
  """
  @spec translate(t(), number(), number()) :: {:ok, t()} | {:error, term()}
  def translate(m, x, y), do: Native.matrix2d_translate(m, x * 1.0, y * 1.0)

  @doc """
  Same as `translate/3`, but returns the translated matrix directly.

  On success, returns `matrix`.

  On failure, raises `Blendend.Error`.
  """
  @spec translate!(t(), number(), number()) :: t()
  def translate!(m, x, y) do
    case translate(m, x, y) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_translate, reason)
    end
  end

  @doc """
  Skews (shears) the matrix by angles `kx` and `ky` (radians) and returns a new matrix.

  On success, returns `{:ok, matrix}`.

  On failure, returns `{:error, reason}`.
  """
  @spec skew(t(), number(), number()) :: {:ok, t()} | {:error, term()}
  def skew(matrix, kx, ky), do: Native.matrix2d_skew(matrix, kx * 1.0, ky * 1.0)

  @doc """
  Same as `skew/3`, but returns the skewed matrix directly.

  On success, returns `matrix`.

  On failure, raises `Blendend.Error`.
  """
  @spec skew!(t(), number(), number()) :: t()
  def skew!(m, kx, ky) do
    case skew(m, kx, ky) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_skew, reason)
    end
  end

  @doc """
  Scales the matrix by `sx` and `sy`, returning a new matrix.

  On success, returns `{:ok, matrix}`.

  On failure, returns `{:error, reason}`.
  """
  @spec scale(t(), number(), number()) :: {:ok, t()} | {:error, term()}
  def scale(m, sx, sy), do: Native.matrix2d_scale(m, sx * 1.0, sy * 1.0)

  @doc """
  Same as `scale/3`, but returns the scaled matrix directly.

  On success, returns `matrix`.

  On failure, raises `Blendend.Error`.
  """
  @spec scale!(t(), number(), number()) :: t()
  def scale!(m, sx, sy) do
    case scale(m, sx, sy) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_scale, reason)
    end
  end

  @doc """
  Rotates the matrix by `angle` radians around the origin, returning a new matrix.

  On success, returns `{:ok, matrix}`.

  On failure, returns `{:error, reason}`.
  """
  @spec rotate(t(), number()) :: {:ok, t()} | {:error, term()}
  def rotate(m, angle_rad), do: Native.matrix2d_rotate(m, angle_rad * 1.0)

  @doc """
  Same as `rotate/2`, but returns the rotated matrix directly.

  On success, returns `matrix`.

  On failure, raises `Blendend.Error`.
  """
  @spec rotate!(t(), number()) :: t()
  def rotate!(m, angle_rad) do
    case rotate(m, angle_rad) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_rotate, reason)
    end
  end

  @doc """
  Post-translate the matrix by `(tx, ty)` (applied after existing transforms).
  """
  @spec post_translate(t(), number(), number()) :: {:ok, t()} | {:error, term()}
  def post_translate(m, tx, ty), do: Native.matrix2d_post_translate(m, tx * 1.0, ty * 1.0)

  @doc """
  Same as `post_translate/3`, but raises on error and returns the matrix.
  """
  @spec post_translate!(t(), number(), number()) :: t()
  def post_translate!(m, tx, ty) do
    case post_translate(m, tx, ty) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_post_translate, reason)
    end
  end

  # ===========================================================================
  # Convenience constructors
  # ===========================================================================

  @doc """
  Returns a new matrix that represents a translation by `{tx, ty}`.

  This is equivalent to:

      identity!() |> translate!(tx, ty)
  """
  @spec translation(number(), number()) :: t()
  def translation(tx, ty) do
    identity!()
    |> translate!(tx, ty)
  end

  @doc """
  Returns a new matrix that represents a rotation by `angle` radians.
  """
  @spec rotation(number()) :: t()
  def rotation(angle) do
    identity!()
    |> rotate!(angle)
  end

  @doc """
  Returns a new matrix that represents scaling by `{sx, sy}`.
  """
  @spec scaling(number(), number()) :: t()
  def scaling(sx, sy) do
    identity!()
    |> scale!(sx, sy)
  end
end
