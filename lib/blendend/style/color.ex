defmodule Blendend.Style.Color do
  @moduledoc """
  Color helpers for the `blendend` drawing API.

  This module works with **color resources** representing RGBA colors and
  provides convenience constructors in RGB, HSL, and HSV. You can also
  read back the RGBA components.
  """

  @typedoc "Opaque color resource (RGBA). Create via rgb!/4, hsl/4, hsv/4."
  @opaque t :: reference()
  alias Blendend.{Native, Error}

  @doc """
  Creates a color in RGBA space.

  All channels are integers in the range `0..255`. The alpha channel
  defaults to `255` (fully opaque).

  On success, returns `{:ok, color}`.

  On failure, returns `{:error, reason}` from the NIF.
  """
  @spec rgb(0..255, 0..255, 0..255, 0..255) :: {:ok, t()} | {:error, term()}
  def rgb(r, g, b, a \\ 255),
    do: Native.color(r, g, b, a)

  @doc """
  Same as `rgb/4`, but returns the color directly and raises on failure.

  On success, returns the color resource.

  On failure, raises `Blendend.Error`.
  """
  @spec rgb!(0..255, 0..255, 0..255, 0..255) :: t()
  def rgb!(r, g, b, a \\ 255) do
    case rgb(r, g, b, a) do
      {:ok, color} -> color
      {:error, reason} -> raise Error.new(:color_rgb, reason)
    end
  end

  @doc """
  Creates a color from HSL (hue–saturation–lightness) plus alpha.

    * `h_deg` – hue in degrees (0–360)
    * `s` – saturation 0.0–1.0
    * `l` – lightness 0.0–1.0
    * `a` – alpha 0–255 (default 255)

  Returns an RGBA color resource. Values outside the typical ranges are
  not clamped; pass normalized inputs.
  """
  @spec hsl(number(), number(), number(), 0..255) :: t()
  def hsl(h_deg, s, l, a \\ 255) do
    {r, g, b} = hsl_to_rgb(h_deg, s, l)
    rgb!(r, g, b, a)
  end

  @doc """
  Creates a color from HSV (hue–saturation–value) plus alpha.

    * `h_deg` – hue in degrees (0–360)
    * `s` – saturation 0.0–1.0
    * `v` – value (brightness) 0.0–1.0
    * `a` – alpha 0–255 (default 255)

  Returns an RGBA color resource. Inputs are expected to be normalized.
  """
  @spec hsv(number(), number(), number(), 0..255) :: t()
  def hsv(h_deg, s, v, a \\ 255) do
    {r, g, b} = hsv_to_rgb(h_deg, s, v)
    rgb!(r, g, b, a)
  end

  # Based on https://en.wikipedia.org/wiki/HSL_and_HSV#HSL_to_RGB_alternative
  defp hsl_to_rgb(h_deg, s, l) do
    # h_deg in 0..360
    # s, l in 0.0..1.0
    a = s * min(l, 1.0 - l)

    k = fn n ->
      :math.fmod(n + h_deg / 30.0, 12.0)
    end

    f = fn n ->
      v =
        l - a * max(-1.0, min(min(k.(n) - 3.0, 9.0 - k.(n)), 1.0))

      round(v * 255)
    end

    {f.(0), f.(8), f.(4)}
  end

  # Based on https://en.wikipedia.org/wiki/HSL_and_HSV#HSL_to_RGB_alternative
  defp hsv_to_rgb(h_deg, s, v) do
    k = fn n ->
      :math.fmod(n + h_deg / 60.0, 6.0)
    end

    f = fn n ->
      l =
        v - v * s * max(0, min(min(k.(n), 4.0 - k.(n)), 1.0))

      round(l * 255)
    end

    {f.(5), f.(3), f.(1)}
  end

  @doc """
  Creates a random `t:t/0`.
  """
  @spec random() :: Color.t()
  def random() do
    rgb!(
      Enum.random(0..255),
      Enum.random(0..255),
      Enum.random(0..255)
    )
  end

  @doc """
  Returns the RGBA components of a color as integers `0..255`.

  On success, returns `{:ok, {r, g, b, a}}`.

  On failure, returns `{:error, reason}`.
  """
  @spec components(t()) :: {:ok, {0..255, 0..255, 0..255, 0..255}} | {:error, term()}
  def components(color), do: Native.color_components(color)

  @doc """
  Same as `components/1`, but raises on failure.
  """
  @spec components!(t()) :: {0..255, 0..255, 0..255, 0..255}
  def components!(color) do
    case components(color) do
      {:ok, tuple} -> tuple
      {:error, reason} -> raise Error.new(:color_components, reason)
    end
  end

  @doc """
  Convenience helper that accepts either `{h, s, v}` or positional `h, s, v` (with optional alpha).
  """
  @spec from_hsv({number(), number(), number()}, nil | number(), nil | number(), 0..255) :: t()
  def from_hsv({h, s, v}, nil, nil, a), do: hsv(h, s, v, a)

  @spec from_hsv(number(), number(), number(), 0..255) :: t()
  def from_hsv(h, s, v, a), do: hsv(h, s, v, a)
end
