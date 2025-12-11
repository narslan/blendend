defmodule Blendend.Matrix2D do
  @moduledoc """
  Thin wrapper around blend2d's `BLMatrix2D`.

  Internally this is a NIF resource representing an affine transform:

      | m00  m01  tx |
      | m10  m11  ty |
      |  0    0   1  |

  Functions in this module either create such a matrix or
  combine it with other transforms.

  * `m00, m01, m10, m11` – linear part (scale, rotation, skew)
  * `tx, ty`             – translation
  """

  @typedoc "Opaque affine transform matrix (BLMatrix2D)."
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

  Examples: 
    
      use Blendend.Draw
      m = matrix do
       rotate :math.pi
      end

      {:ok, ml} = Blendend.Matrix2D.to_list(m)
      [-1.0, 0, 0, -1.0, 0.0, 0.0] # floating point noise discarded
     
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
  Returns `matrix * other`, i.e. the `other` transform is applied after `matrix`.

  Examples:

      iex> use Blendend.Draw
      iex> translate = matrix(do: translate(10, 0))
      iex> scale = matrix(do: scale(2, 1))
      iex> {:ok, m} = Blendend.Matrix2D.transform(translate, scale)
      iex> {:ok, list} = Blendend.Matrix2D.to_list(m)
      iex> list
      [2.0, 0.0, 0.0, 1.0, 10.0, 0.0]  # translate first, then scale (translation unchanged)
  """
  @spec transform(t(), t()) :: {:ok, t()} | {:error, term()}
  def transform(m, other), do: Native.matrix2d_transform(m, other)

  @doc """
  Same as `transform/2`, but returns the matrix directly.
  """
  @spec transform!(t(), t()) :: t()
  def transform!(m, other) do
    case transform(m, other) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_transform, reason)
    end
  end

  @doc """
  Returns `other * matrix`, i.e. the `other` transform is applied before `matrix`.

  Examples:

      iex> use Blendend.Draw
      iex> translate = matrix(do: translate(10, 0))
      iex> scale = matrix(do: scale(2, 1))
      iex> {:ok, m} = Blendend.Matrix2D.post_transform(translate, scale)
      iex> {:ok, list} = Blendend.Matrix2D.to_list(m)
      iex> list
      [2.0, 0.0, 0.0, 1.0, 20.0, 0.0]  # scale first, then translate (x translation doubled)
  """
  @spec post_transform(t(), t()) :: {:ok, t()} | {:error, term()}
  def post_transform(m, other), do: Native.matrix2d_post_transform(m, other)

  @doc """
  Same as `post_transform/2`, but returns the matrix directly.
  """
  @spec post_transform!(t(), t()) :: t()
  def post_transform!(m, other) do
    case post_transform(m, other) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_post_transform, reason)
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
  Returns `scale * matrix`, applying the scale before the existing transform.
  """
  @spec post_scale(t(), number(), number()) :: {:ok, t()} | {:error, term()}
  def post_scale(m, sx, sy), do: Native.matrix2d_post_scale(m, sx * 1.0, sy * 1.0)

  @doc """
  Same as `post_scale/3`, but returns the scaled matrix directly.
  """
  @spec post_scale!(t(), number(), number()) :: t()
  def post_scale!(m, sx, sy) do
    case post_scale(m, sx, sy) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_post_scale, reason)
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
  Rotates the matrix by `angle` radians about `{cx, cy}`, returning a new matrix.
  """
  @spec rotate_at(t(), number(), number(), number()) :: {:ok, t()} | {:error, term()}
  def rotate_at(m, angle_rad, cx, cy),
    do: Native.matrix2d_rotate_at(m, angle_rad * 1.0, cx * 1.0, cy * 1.0)

  @doc """
  Same as `rotate_at/4`, but returns the rotated matrix directly.
  """
  @spec rotate_at!(t(), number(), number(), number()) :: t()
  def rotate_at!(m, angle_rad, cx, cy) do
    case rotate_at(m, angle_rad, cx, cy) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_rotate_at, reason)
    end
  end

  @doc """
  Returns `rotation * matrix`, applying the rotation about `{cx, cy}` before the existing transform.
  """
  @spec post_rotate(t(), number(), number(), number()) :: {:ok, t()} | {:error, term()}
  def post_rotate(m, angle_rad, cx, cy),
    do: Native.matrix2d_post_rotate(m, angle_rad * 1.0, cx * 1.0, cy * 1.0)

  @doc """
  Same as `post_rotate/4`, but returns the rotated matrix directly.
  """
  @spec post_rotate!(t(), number(), number(), number()) :: t()
  def post_rotate!(m, angle_rad, cx, cy) do
    case post_rotate(m, angle_rad, cx, cy) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_post_rotate, reason)
    end
  end

  @doc """
  Returns `translation * matrix`, applying `(tx, ty)` before the existing transforms.
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

  @doc """
  Returns `skew * matrix`, applying the shear before the existing transforms.
  """
  @spec post_skew(t(), number(), number()) :: {:ok, t()} | {:error, term()}
  def post_skew(m, kx, ky), do: Native.matrix2d_post_skew(m, kx * 1.0, ky * 1.0)

  @doc """
  Same as `post_skew/3`, but returns the skewed matrix directly.
  """
  @spec post_skew!(t(), number(), number()) :: t()
  def post_skew!(m, kx, ky) do
    case post_skew(m, kx, ky) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_post_skew, reason)
    end
  end

  @doc """
  Inverts the matrix, returning a new matrix.

  Examples:

      iex> use Blendend.Draw
      iex> scale = matrix(do: scale(2, 1))
      iex> Blendend.Matrix2D.invert!(scale) |> Blendend.Matrix2D.to_list!
      [0.5, -0.0, -0.0, 1.0, -0.0, -0.0]
  """
  @spec invert(t()) :: {:ok, t()} | {:error, term()}
  def invert(m), do: Native.matrix2d_invert(m)

  @doc """
  Same as `invert/1`, but returns the matrix directly.
  """
  @spec invert!(t()) :: t()
  def invert!(m) do
    case invert(m) do
      {:ok, m2} -> m2
      {:error, reason} -> raise Error.new(:matrix2d_invert, reason)
    end
  end

  @doc """
  Maps a point `{x, y}` through the matrix, returning `{ok, {x, y}}`.
  """
  @spec map_point(t(), number(), number()) :: {:ok, {number(), number()}} | {:error, term()}
  def map_point(m, x, y), do: Native.matrix2d_map_point(m, x * 1.0, y * 1.0)

  @doc """
  Same as `map_point/3`, but returns the tuple directly.
  """
  @spec map_point!(t(), number(), number()) :: {number(), number()}
  def map_point!(m, x, y) do
    case map_point(m, x, y) do
      {:ok, {nx, ny}} -> {nx, ny}
      {:error, reason} -> raise Error.new(:matrix2d_map_point, reason)
    end
  end

  @doc """
  Maps a vector `{x, y}` through the matrix (ignores translation), returning `{ok, {x, y}}`.

  Examples:

      iex> use Blendend.Draw
      iex> scale = matrix(do: scale(2, 1))
      iex> Blendend.Matrix2D.map_vector!(scale, 2, 3)
      {4.0, 3.0}

      iex> translate = matrix(do: translate(10, 10))
      iex> Blendend.Matrix2D.map_vector!(translate, 2, 3)
      {2.0, 3.0}
  """
  @spec map_vector(t(), number(), number()) :: {:ok, {number(), number()}} | {:error, term()}
  def map_vector(m, x, y), do: Native.matrix2d_map_vector(m, x * 1.0, y * 1.0)

  @doc """
  Same as `map_vector/3`, but returns the tuple directly.
  """
  @spec map_vector!(t(), number(), number()) :: {number(), number()}
  def map_vector!(m, x, y) do
    case map_vector(m, x, y) do
      {:ok, {nx, ny}} -> {nx, ny}
      {:error, reason} -> raise Error.new(:matrix2d_map_vector, reason)
    end
  end

  @doc """
  Constructs a matrix from precomputed `sin`/`cos` and optional translation `tx/ty`.
  """
  @spec make_sin_cos(number(), number(), number(), number()) :: {:ok, t()} | {:error, term()}
  def make_sin_cos(sin, cos, tx \\ 0.0, ty \\ 0.0),
    do: Native.matrix2d_make_sin_cos(sin * 1.0, cos * 1.0, tx * 1.0, ty * 1.0)

  @doc """
  Same as `make_sin_cos/4`, but returns the matrix directly.
  """
  @spec make_sin_cos!(number(), number(), number(), number()) :: t()
  def make_sin_cos!(sin, cos, tx \\ 0.0, ty \\ 0.0) do
    case make_sin_cos(sin, cos, tx, ty) do
      {:ok, m} -> m
      {:error, reason} -> raise Error.new(:matrix2d_make_sin_cos, reason)
    end
  end
end
