defmodule Blendend.CanvasTransformTest do
  use ExUnit.Case, async: true
  alias Blendend.{Canvas, Matrix2D}

  defp assert_floats_close(list1, list2, eps \\ 1.0e-9) do
    Enum.zip(list1, list2)
    |> Enum.each(fn {a, b} ->
      assert abs(a - b) <= eps, "expected #{a} ≈ #{b}"
    end)
  end

  test "translate context updates user_transform" do
    {:ok, c} = Canvas.new(100, 100)
    :ok = Canvas.translate(c, 10.0, 5.0)

    m = c |> Canvas.user_transform!() |> Matrix2D.to_list!()
    assert_floats_close(m, [1.0, 0.0, 0.0, 1.0, 10.0, 5.0])
  end

  test "scale context updates user_transform" do
    {:ok, c} = Canvas.new(100, 100)
    :ok = Canvas.scale(c, 2.0, 3.0)

    m = c |> Canvas.user_transform!() |> Matrix2D.to_list!()
    assert_floats_close(m, [2.0, 0.0, 0.0, 3.0, 0.0, 0.0])
  end

  test "rotate context matches Matrix2D.rotate" do
    angle = :math.pi() / 2

    # expected via pure Matrix2D
    m_expected =
      Matrix2D.identity!()
      |> Matrix2D.rotate!(angle)
      |> Matrix2D.to_list!()

    {:ok, ctx} = Canvas.new(100, 100)
    :ok = Canvas.rotate(ctx, angle)

    m_ctx =
      ctx
      |> Canvas.user_transform!()
      |> Matrix2D.to_list!()

    assert_floats_close(m_ctx, m_expected)
  end

  test "skew context matches Matrix2D.skew" do
    kx = 0.3
    ky = -0.2

    m_expected =
      Matrix2D.identity!()
      |> Matrix2D.skew!(kx, ky)
      |> Matrix2D.to_list!()

    {:ok, ctx} = Canvas.new(100, 100)
    :ok = Canvas.skew(ctx, kx, ky)

    m_ctx =
      ctx
      |> Canvas.user_transform!()
      |> Matrix2D.to_list!()

    assert_floats_close(m_ctx, m_expected)
  end

  test "apply_transform composes with current context transform" do
    {:ok, ctx} = Canvas.new(100, 100)

    # start with a translation on the canvas
    :ok = Canvas.translate(ctx, 10.0, 5.0)

    # build a matrix that scales by (2, 3)
    m_scale =
      Matrix2D.identity!()
      |> Matrix2D.scale!(2.0, 3.0)

    # apply to context
    :ok = Canvas.apply_transform(ctx, m_scale)

    m_ctx =
      ctx
      |> Canvas.user_transform!()
      |> Matrix2D.to_list!()

    # expected = translation then scale, in terms of Matrix2D
    m_expected =
      Matrix2D.identity!()
      |> Matrix2D.translate!(10.0, 5.0)
      |> Matrix2D.transform!(m_scale)
      |> Matrix2D.to_list!()

    assert_floats_close(m_ctx, m_expected)
  end

  test "save_state/restore_state round-trips transforms" do
    {:ok, ctx} = Canvas.new(50, 50)
    :ok = Canvas.translate(ctx, 5.0, 7.0)
    :ok = Canvas.save_state(ctx)

    :ok = Canvas.scale(ctx, 2.0, 2.0)
    m_scaled = ctx |> Canvas.user_transform!() |> Matrix2D.to_list!()
    refute m_scaled == [1.0, 0.0, 0.0, 1.0, 5.0, 7.0]

    :ok = Canvas.restore_state(ctx)
    m_restored = ctx |> Canvas.user_transform!() |> Matrix2D.to_list!()
    assert_floats_close(m_restored, [1.0, 0.0, 0.0, 1.0, 5.0, 7.0])
  end

  test "inverse translation resets the transform via apply_transform" do
    {:ok, ctx} = Canvas.new(100, 100)

    :ok = Canvas.translate(ctx, 12.0, -4.0)
    t_inv = Matrix2D.translate!(Matrix2D.identity!(), -12.0, 4.0)
    :ok = Canvas.apply_transform(ctx, t_inv)

    m = ctx |> Canvas.user_transform!() |> Matrix2D.to_list!()
    assert_floats_close(m, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])
  end

  test "initial user_transform is identity" do
    {:ok, ctx} = Canvas.new(100, 100)

    m =
      ctx
      |> Canvas.user_transform!()
      |> Matrix2D.to_list!()

    assert_floats_close(m, [1.0, 0.0, 0.0, 1.0, 0.0, 0.0])
  end
end
