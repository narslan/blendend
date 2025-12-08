defmodule Blendend.Style.Pattern do
  @moduledoc """

  A pattern wraps a `Blendend.Image` and can be used as a fill **or** stroke
  style via canvas operations (for example by passing `fill: pattern` in style
  options).

  *Use patterns when you want an image as "paint" inside shapes or text.*

  A pattern wraps a `Blendend.Image.t()` and can be used as a fill **or** stroke
  style via canvas operations (for example by passing `fill: pat` in style
  options).

  Example:

      img = Blendend.Image.from_file!("texture.png")
      pat        = Blendend.Style.Pattern.create!(img)

      # used as fill:
      rect 0, 0, 400, 400, fill: pat
  """

  alias Blendend.Native
  alias Blendend.{Image, Matrix2D, Error}

  @opaque t :: reference()

  @type extend_mode ::
          :pad
          | :repeat
          | :reflect
          | :pad_x_repeat_y
          | :pad_x_reflect_y
          | :repeat_x_pad_y
          | :repeat_x_reflect_y
          | :reflect_x_pad_y
          | :reflect_x_repeat_y

  @doc """
  Creates a pattern from an existing `Blendend.Image`.

  Returns `{:ok, pattern}` or `{:error, reason}`.
  """
  @spec create(Image.t()) :: {:ok, t()} | {:error, term()}
  def create(img), do: Native.pattern_create(img)

  @doc """
  Same as `create/1`, but raises on failure.

  On success, returns `pattern`.

  On failure, raises `Blendend.Error`.
  """
  @spec create!(Image.t()) :: t()
  def create!(img) do
    case create(img) do
      {:ok, pat} -> pat
      {:error, reason} -> raise Error.new(:pattern_create, reason)
    end
  end

  @doc """
  Sets the extend mode used when sampling a pattern.

  The extend mode decides how the pattern is sampled when coordinates land
  outside the wrapped image. Supported modes:

    * `:pad` / `:repeat` / `:reflect` – apply the mode on both axes
    * `:pad_x_repeat_y` / `:pad_x_reflect_y` – pad on X, repeat or reflect on Y
    * `:repeat_x_pad_y` / `:repeat_x_reflect_y` – repeat on X, pad or reflect on Y
    * `:reflect_x_pad_y` / `:reflect_x_repeat_y` – reflect on X, pad or repeat on Y

  Returns `:ok` or `{:error, reason}`.
  """
  @spec set_extend(t(), extend_mode()) :: :ok | {:error, term()}
  def set_extend(pattern, mode),
    do: Native.pattern_set_extend(pattern, mode)

  @doc """
  Sets the transform matrix used when sampling a pattern.
  """
  @spec set_transform(t(), Matrix2D.t()) :: :ok | {:error, term()}
  def set_transform(pattern, matrix),
    do: Native.pattern_set_transform(pattern, matrix)

  @doc """
  Resets the pattern's transform back to identity.
  """
  @spec reset_transform(t()) :: :ok | {:error, term()}
  def reset_transform(pattern),
    do: Native.pattern_reset_transform(pattern)
end
