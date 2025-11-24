defmodule Blendend.Test.ImageHelpers do
  @moduledoc false
  alias Blendend.Image

  @type decoded :: %{width: pos_integer(), height: pos_integer(), data: binary()}

  def decode_qoi!(bin) do
    case Image.decode_qoi(bin) do
      {:ok, {w, h, data}} -> %{width: w, height: h, data: data}
      {:error, reason} -> raise "decode_qoi failed: #{inspect(reason)}"
    end
  end

  def pixel_at(%{width: w, data: data}, x, y) when x < w do
    idx = (y * w + x) * 4
    <<_::binary-size(^idx), r::8, g::8, b::8, a::8, _::binary>> = data
    {r, g, b, a}
  end
end
