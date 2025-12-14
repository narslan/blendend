defmodule Blendend.DrawHsvTest do
  use ExUnit.Case, async: true
  use Blendend.Draw

  test "hsv supports {h, s, v} tuples" do
    color = hsv({0, 1.0, 1.0})
    assert {255, 0, 0, 255} == Blendend.Style.Color.components!(color)
  end

  test "hsv supports {h, s, v} tuple expressions" do
    tuple = {0, 1.0, 1.0}
    color = hsv(tuple)
    assert {255, 0, 0, 255} == Blendend.Style.Color.components!(color)
  end

  test "hsv supports {h, s, v, a} tuples" do
    color = hsv({0, 1.0, 1.0, 128})
    assert {255, 0, 0, 128} == Blendend.Style.Color.components!(color)
  end
end
