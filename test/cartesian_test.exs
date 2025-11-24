defmodule Blendend.CartesianTest do
  use ExUnit.Case, async: true
  alias Blendend.Cartesian

  defp assert_pt({ax, ay}, {ex, ey}, eps \\ 1.0e-6) do
    assert_in_delta(ax, ex, eps)
    assert_in_delta(ay, ey, eps)
  end

  describe "corner mappings (y inverted)" do
    test "docs example holds" do
      f = Cartesian.new!(-:math.pi(), :math.pi(), -1.0, 1.0, 500, 500)
      assert_pt(Cartesian.to_canvas!(f, -:math.pi(), 1.0), {0.0, 0.0})
      assert_pt(Cartesian.to_canvas!(f, :math.pi(), -1.0), {500.0, 500.0})
      assert_pt(Cartesian.to_canvas!(f, 0.0, 0.0), {250.0, 250.0})
      assert_pt(Cartesian.to_canvas!(f, 0.0, 1.0), {250.0, 0.0})
    end
  end

  describe "round-trip math <-> canvas" do
    test "to_canvas → to_math ≈ identity" do
      f = Cartesian.new!(-2.0, 3.0, -1.0, 1.0, 200, 100)

      for {mx, my} <- [{-2.0, -1.0}, {0.0, 0.0}, {2.5, 0.5}] do
        {cx, cy} = Cartesian.to_canvas!(f, mx, my)
        {mx2, my2} = Cartesian.to_math!(f, cx, cy)
        assert_in_delta(mx, mx2, 1.0e-6)
        assert_in_delta(my, my2, 1.0e-6)
      end
    end

    test "round-trips hold for random points within bounds" do
      :rand.seed(:exsss, {101, 202, 303})
      f = Cartesian.new!(-5.0, 5.0, -2.5, 2.5, 300, 120)

      boundary =
        for x <- [-5.0, 0.0, 5.0], y <- [-2.5, 0.0, 2.5], do: {x, y}

      randoms =
        for _ <- 1..20 do
          {(:rand.uniform() * 10.0) - 5.0, (:rand.uniform() * 5.0) - 2.5}
        end

      for {mx, my} <- boundary ++ randoms do
        {cx, cy} = Cartesian.to_canvas!(f, mx, my)
        {mx2, my2} = Cartesian.to_math!(f, cx, cy)
        assert_in_delta(mx, mx2, 1.0e-5)
        assert_in_delta(my, my2, 1.0e-5)
      end
    end
  end

  describe "non-bang variants" do
    test "return {:ok, ...} tuples" do
      {:ok, f} = Cartesian.new(-1.0, 1.0, -1.0, 1.0, 100, 100)
      assert {:ok, {50.0, 50.0}} = Cartesian.to_canvas(f, 0.0, 0.0)
      assert {:ok, {-1.0, 1.0}} = Cartesian.to_math(f, 0.0, 0.0)
    end
  end
end
