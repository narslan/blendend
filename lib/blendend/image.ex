defmodule Blendend.Image do
  @moduledoc """
  Image loading functions for Blendend.

  This module deals with **image resources** that can be used anywhere pixel data
  is needed: as sources for patterns, or passed directly to canvas blit calls.

  Typical uses:
    * create a tiling or transformed fill via `Blendend.Style.Pattern.create/1`
    * draw an image onto a canvas via `Blendend.Canvas.blit_image/4` (or `/6`)
  """

  @typedoc "Opaque image resource (pixel buffer). Load via from_file!/1 or from_data/1."
  @opaque t :: reference()

  alias Blendend.Native
  alias Blendend.Error

  @doc """
  Loads an image from `path`.

  This reads the file in Elixir and lets the NIF decode the bytes. The file
  must be in a format blend2d understands (e.g. PNG, JPEG, BMP, QOI ).

  On success, returns `{:ok, image}` where `image` is an opaque resource.

  On failure, returns `{:error, reason}`.
  """
  @spec from_file(String.t()) :: {:ok, t()} | {:error, term()}
  def from_file(path) when is_binary(path) do
    with {:ok, bin} <- File.read(path) do
      from_data(bin)
    end
  end

  @doc """
  Same as `from_file/1`, but returns the image directly.

  On success, returns `image`.

  On failure, raises `Blendend.Error`.
  """
  @spec from_file!(String.t()) :: t()
  def from_file!(path) do
    case from_file(path) do
      {:ok, img} -> img
      {:error, reason} -> raise Error.new(:image_from_file, reason)
    end
  end

  @doc """
  Loads an image from an in-memory binary.

  The binary is the raw image file contents.

  On success, returns `{:ok, image}`.

  On failure, returns `{:error, reason}`.
  """
  @spec from_data(binary()) :: {:ok, t()} | {:error, term()}
  def from_data(bin) when is_binary(bin),
    do: Native.image_read_from_data(bin)

  @doc """
  Returns the image size in pixels.

  On success, returns `{:ok, {width, height}}` where dimensions are in pixels.

  On failure, returns `{:error, reason}`.
  """
  @spec size(t()) ::
          {:ok, {non_neg_integer(), non_neg_integer()}} | {:error, term()}
  def size(image), do: Native.image_size(image)

  @doc """
  Reads a single pixel from `image` at `{x, y}`.

  Returns the color as `{r, g, b, a}` (0..255), with **straight alpha**
  (Blend2D stores PRGB32 in premultiplied form).
  """
  @spec pixel_at(t(), non_neg_integer(), non_neg_integer()) ::
          {:ok, {0..255, 0..255, 0..255, 0..255}} | {:error, term()}
  def pixel_at(image, x, y) when is_integer(x) and is_integer(y) and x >= 0 and y >= 0 do
    Native.image_get_pixel(image, x, y)
  end

  @doc """
  Same as `pixel_at/3`, but returns the pixel tuple directly and raises on failure.
  """
  @spec pixel_at!(t(), non_neg_integer(), non_neg_integer()) :: {0..255, 0..255, 0..255, 0..255}
  def pixel_at!(image, x, y) do
    case pixel_at(image, x, y) do
      {:ok, rgba} -> rgba
      {:error, reason} -> raise Error.new(:image_get_pixel, reason)
    end
  end

  @doc """
  Same as `size/1`, but returns the `{width, height}` tuple directly.

  On success, returns `{width, height}`.

  On failure, raises `Blendend.Error`.
  """
  @spec size!(t()) :: {non_neg_integer(), non_neg_integer()}
  def size!(image) do
    case size(image) do
      {:ok, dimensions} -> dimensions
      {:error, reason} -> raise Error.new(:image_size, reason)
    end
  end

  @doc """
  Decodes a QOI binary into raw RGBA bytes for tests and diagnostics.

  Returns `{:ok, {width, height, data}}` where `data` is a binary of
  length `width * height * 4` in **RGBA** byte order.
  """
  @spec decode_qoi(binary()) :: {:ok, {pos_integer(), pos_integer(), binary()}} | {:error, term()}
  def decode_qoi(bin), do: Native.image_decode_qoi(bin)

  @spec decode_qoi!(binary()) :: {pos_integer(), pos_integer(), binary()}
  def decode_qoi!(bin) do
    case decode_qoi(bin) do
      {:ok, tuple} -> tuple
      {:error, reason} -> raise Error.new(:image_decode_qoi, reason)
    end
  end

  @doc """
  Returns a blurred copy of `image` using a Gaussian approximation.

  `sigma` controls blur strength in pixels (roughly 3×sigma is the visible radius).
  Supports PRGB32 and A8 images; other formats are converted to PRGB32 first.
  """
  @spec blur(t(), number()) :: {:ok, t()} | {:error, term()}
  def blur(image, sigma) when is_number(sigma), do: Native.image_blur(image, sigma * 1.0)

  @doc """
  Same as `blur/2`, but returns the blurred image or raises on failure.
  """
  @spec blur!(t(), number()) :: t()
  def blur!(image, sigma) do
    case blur(image, sigma) do
      {:ok, img} -> img
      {:error, reason} -> raise Error.new(:image_blur, reason)
    end
  end

  @doc """
  Loads an image from `path` and converts it to an 8-bit mask using the given channel.

  Channel can be `:red` (default), `:green`, `:blue`, `:alpha`, or `:luma`.
  """
  @spec from_file_a8(String.t(), atom()) :: {:ok, t()} | {:error, term()}
  def from_file_a8(path, channel \\ :red) when is_binary(path) do
    with {:ok, bin} <- File.read(path) do
      from_data_a8(bin, channel)
    end
  end

  @doc """
  Same as `from_file_a8/2`, but raises on failure.
  """
  @spec from_file_a8!(String.t(), atom()) :: t()
  def from_file_a8!(path, channel \\ :red) do
    case from_file_a8(path, channel) do
      {:ok, img} -> img
      {:error, reason} -> raise Error.new(:image_from_file_a8, reason)
    end
  end

  @doc """
  Loads image data from a binary and converts it to A8 (alpha-only) using the given channel.
  """
  @spec from_data_a8(binary(), atom()) :: {:ok, t()} | {:error, term()}
  def from_data_a8(bin, channel \\ :red) when is_binary(bin) and is_atom(channel),
    do: Native.image_read_mask_from_data(bin, channel)
end
