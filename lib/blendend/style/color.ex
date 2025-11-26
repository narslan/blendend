defmodule Blendend.Style.Color do
  @moduledoc """
  Color helpers for the `blendend` drawing API.

  This module works with **color resources** representing RGBA colors and
  provides convenience constructors in RGB, HSL, and HSV.
  """

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

  @spec random() :: Color.t()
  def random() do
    rgb!(
      Enum.random(0..255),
      Enum.random(0..255),
      Enum.random(0..255)
    )
  end

  # Palette set adapted from takawo (https://openprocessing.org/user/6533) —
  # used here to ease multicolor experimentation.
  @scheme_palette %{
    benedictus: ["#F27EA9", "#366CD9", "#5EADF2", "#636E73", "#F2E6D8"],
    cross: ["#D962AF", "#58A6A6", "#8AA66F", "#F29F05", "#F26D6D"],
    demuth: ["#222940", "#D98E04", "#F2A950", "#BF3E21", "#F2F2F2"],
    hiroshige: ["#1B618C", "#55CCD9", "#F2BC57", "#F2DAAC", "#F24949"],
    hokusai: ["#074A59", "#F2C166", "#F28241", "#F26B5E", "#F2F2F2"],
    hokusai_blue: ["#023059", "#459DBF", "#87BF60", "#D9D16A", "#F2F2F2"],
    java: ["#632973", "#02734A", "#F25C05", "#F29188", "#F2E0DF"],
    kandinsky: ["#8D95A6", "#0A7360", "#F28705", "#D98825", "#F2F2F2"],
    monet: ["#4146A6", "#063573", "#5EC8F2", "#8C4E03", "#D98A29"],
    nizami: ["#034AA6", "#72B6F2", "#73BFB1", "#F2A30F", "#F26F63"],
    renoir: ["#303E8C", "#F2AE2E", "#F28705", "#D91414", "#F2F2F2"],
    vangogh: ["#424D8C", "#84A9BF", "#C1D9CE", "#F2B705", "#F25C05"],
    mono: ["#D9D7D8", "#3B5159", "#5D848C", "#7CA2A6", "#262321"]
  }

  @doc """
  Returns a list of RGBA colors from a named scheme.

  Accepts atoms for the scheme name (e.g., `:hokusai_blue`).
  Use `scheme_names/0` to see available options. Passing `:random` picks a random scheme.

      iex> Blendend.Style.Color.scheme(:hokusai) |> length()
      5
      iex> Blendend.Style.Color.scheme(:random) |> is_list()
      true
  """
  @spec scheme(atom()) :: [t()]
  def scheme(name) when is_atom(name) do
    key =
      case name do
        :random -> random_scheme_key()
        atom -> atom
      end

    palette =
      Map.fetch(@scheme_palette, key)
      |> case do
        {:ok, list} -> list
        :error -> Map.fetch!(@scheme_palette, random_scheme_key())
      end

    Enum.map(palette, &hex_to_color!/1)
  end

  def scheme(name) do
    raise ArgumentError,
          "scheme/1 expects an atom scheme name such as :hokusai or :random, got: #{inspect(name)}"
  end

  @doc """
  Lists available scheme names as atoms.
  """
  @spec scheme_names() :: [atom()]
  def scheme_names, do: Map.keys(@scheme_palette)

  defp random_scheme_key, do: Enum.random(Map.keys(@scheme_palette))

  defp hex_to_color!("#" <> <<r::binary-size(2), g::binary-size(2), b::binary-size(2)>>) do
    rgb!(
      String.to_integer(r, 16),
      String.to_integer(g, 16),
      String.to_integer(b, 16)
    )
  end
end
