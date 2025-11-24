defmodule Blendend.Native do
  @moduledoc false

  @on_load :load_nif
  def load_nif do
    path = :filename.join(:code.priv_dir(:blendend), ~c"blendend")
    :erlang.load_nif(path, 0)
  end

  def canvas_new(_w, _h), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_save(_canvas, _path), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_clear(_canvas, _opts), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_save_state(_canvas), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_restore_state(_canvas), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_apply_transform(_canvas, _matrix), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_user_transform(_canvas), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_set_transform(_canvas, _matrix), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_reset_transform(_canvas), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_set_stroke_width(_canvas, _width), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_set_stroke_style(_canvas, _style), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_translate(_canvas, _x, _y), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_post_translate(_canvas, _x, _y), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_scale(_c, _sx, _sy),
    do: :erlang.nif_error(:nif_not_loaded)

  def canvas_rotate(_c, _angle),
    do: :erlang.nif_error(:nif_not_loaded)

  def canvas_skew(_c, _kx, _ky),
    do: :erlang.nif_error(:nif_not_loaded)

  def canvas_clip_to_rect(_c, _x, _y, _w, _h), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_fill_mask(_c, _img, _x, _y), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_fill_mask(_c, _img, _x, _y, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_set_fill_rule(_canvas, _rule), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_set_comp_op(_canvas, _op), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_to_png_base64(_canvas), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_to_png(_canvas), do: :erlang.nif_error(:nif_not_loaded)
  def canvas_to_qoi(_canvas), do: :erlang.nif_error(:nif_not_loaded)

  # ------------------------
  # Image
  # ------------------------
  def image_size(_image), do: :erlang.nif_error(:nif_not_loaded)
  def image_read_from_data(_binary), do: :erlang.nif_error(:nif_not_loaded)
  def image_read_mask_from_data(_binary, _channel), do: :erlang.nif_error(:nif_not_loaded)
  def image_decode_qoi(_binary), do: :erlang.nif_error(:nif_not_loaded)

  # ------------------------
  # Cartesian
  # ------------------------
  def cartesian(_ox, _oy, _sx, _sy, _wx, _wy), do: :erlang.nif_error(:nif_not_loaded)
  def cartesian_to_canvas(_canvas, _cartesian, _opts), do: :erlang.nif_error(:nif_not_loaded)
  def cartesian_to_math(_canvas, _cartesian, _opts), do: :erlang.nif_error(:nif_not_loaded)

  # ------------------------
  # Styles
  # ------------------------
  def color(_r, _g, _b, _a), do: :erlang.nif_error(:nif_not_loaded)
  def gradient_linear(_x0, _y0, _x1, _y1), do: :erlang.nif_error(:nif_not_loaded)
  def gradient_radial(_cx, _cy, _r, _fx, _fy), do: :erlang.nif_error(:nif_not_loaded)
  def gradient_conic(_cx, _cy, _angle), do: :erlang.nif_error(:nif_not_loaded)
  def gradient_add_stop(_grad, _offset, _color), do: :erlang.nif_error(:nif_not_loaded)
  def gradient_set_extend(_grad, _extend_mode), do: :erlang.nif_error(:nif_not_loaded)
  def gradient_set_transform(_grad, _matrix), do: :erlang.nif_error(:nif_not_loaded)
  def gradient_reset_transform(_grad), do: :erlang.nif_error(:nif_not_loaded)

  def pattern_create(_img), do: :erlang.nif_error(:nif_not_loaded)
  def pattern_set_extend(_pattern, _extend_mode), do: :erlang.nif_error(:nif_not_loaded)
  def pattern_set_transform(_pattern, _matrix), do: :erlang.nif_error(:nif_not_loaded)
  def pattern_reset_transform(_pattern), do: :erlang.nif_error(:nif_not_loaded)

  # ------------------------
  # Path
  # ------------------------
  def path_new(), do: :erlang.nif_error(:nif_not_loaded)
  def path_set_vertex_at(_p, _idx, _cmd, _x, _y), do: :erlang.nif_error(:nif_not_loaded)
  def path_vertex_count(_p), do: :erlang.nif_error(:nif_not_loaded)
  def path_vertex_at(_p, _idx), do: :erlang.nif_error(:nif_not_loaded)
  def path_shrink(_p), do: :erlang.nif_error(:nif_not_loaded)
  def path_debug_dump(_p), do: :erlang.nif_error(:nif_not_loaded)

  def path_move_to(_p, _x, _y), do: :erlang.nif_error(:nif_not_loaded)
  def path_line_to(_p, _x, _y), do: :erlang.nif_error(:nif_not_loaded)
  def path_quad_to(_p, _x1, _y1, _x2, _y2), do: :erlang.nif_error(:nif_not_loaded)
  def path_cubic_to(_p, _x1, _y1, _x2, _y2, _x3, _y3), do: :erlang.nif_error(:nif_not_loaded)

  def path_conic_to(_p, _x1, _y1, _x2, _y2, _w),
    do: :erlang.nif_error(:nif_not_loaded)

  def path_smooth_quad_to(_p, _x2, _y2),
    do: :erlang.nif_error(:nif_not_loaded)

  def path_smooth_cubic_to(_p, _x2, _y2, _x3, _y3),
    do: :erlang.nif_error(:nif_not_loaded)

  def path_arc_to(_p, _cx, _cy, _rx, _ry, _start, _sweep, _force?),
    do: :erlang.nif_error(:nif_not_loaded)

  def path_elliptic_arc_to(_p, _rx, _ry, _rot, _large?, _sweep?, _x1, _y1),
    do: :erlang.nif_error(:nif_not_loaded)

  def path_arc_quadrant_to(_p, _x1, _y1, _x2, _y2), do: :erlang.nif_error(:nif_not_loaded)
  def path_add_circle(_p, _cx, _cy, _r), do: :erlang.nif_error(:nif_not_loaded)
  def path_add_path(_dst, _src), do: :erlang.nif_error(:nif_not_loaded)
  def path_add_path_transform(_dst, _src, _mtx), do: :erlang.nif_error(:nif_not_loaded)

  def path_close(_p), do: :erlang.nif_error(:nif_not_loaded)
  def path_hit_test(_p, _x, _y), do: :erlang.nif_error(:nif_not_loaded)
  def path_hit_test(_p, _x, _y, _rule), do: :erlang.nif_error(:nif_not_loaded)
  def path_clear(_p), do: :erlang.nif_error(:nif_not_loaded)
  def path_equals(_p1, _p2), do: :erlang.nif_error(:nif_not_loaded)
  def path_fit_to(_p, _rect_tuple), do: :erlang.nif_error(:nif_not_loaded)

  def path_flatten(_path, _tolerance), do: :erlang.nif_error(:nif_not_loaded)
  # ------------------------
  # Matrix
  # ------------------------
  def matrix2d_new(_list), do: :erlang.nif_error(:nif_not_loaded)
  def matrix2d_identity(), do: :erlang.nif_error(:nif_not_loaded)
  def matrix2d_to_list(_matrix), do: :erlang.nif_error(:nif_not_loaded)
  def matrix2d_translate(_matrix, _x0, _y0), do: :erlang.nif_error(:nif_not_loaded)
  def matrix2d_post_translate(_matrix, _x0, _y0), do: :erlang.nif_error(:nif_not_loaded)
  def matrix2d_skew(_matrix, _kx, _ky), do: :erlang.nif_error(:nif_not_loaded)
  def matrix2d_scale(_matrix, _sx, _sy), do: :erlang.nif_error(:nif_not_loaded)
  def matrix2d_rotate(_matrix, _angle), do: :erlang.nif_error(:nif_not_loaded)
  def matrix2d_compose(_matrix1, _matrix2), do: :erlang.nif_error(:nif_not_loaded)
  # ------------------------
  # Fill shapes 
  # ------------------------
  def canvas_fill_path(_canvas, _path, _opts \\ []), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_fill_box(_canvas, _arg1, _arg2, _arg3, _arg4, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_fill_rect(_canvas, _arg1, _arg2, _arg3, _arg4, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_fill_circle(_canvas, _arg1, _arg2, _arg3, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_fill_ellipse(_canvas, _arg1, _arg2, _arg3, _arg4, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_fill_round_rect(_canvas, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_fill_chord(_canvas, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_fill_pie(_canvas, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_fill_triangle(_canvas, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_fill_polygon(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_fill_box_array(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_fill_rect_array(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  # Stroke Shapes
  def canvas_stroke_path(_canvas, _path, _opts \\ []), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_stroke_line(_canvas, _arg1, _arg2 \\ nil, _arg3 \\ nil, _arg4 \\ nil, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_rect(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_rect(_canvas, _arg1, _arg2, _arg3, _arg4, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_box(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_box(_canvas, _arg1, _arg2, _arg3, _arg4, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_circle(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_circle(_canvas, _arg1, _arg2, _arg3, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_ellipse(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_ellipse(_canvas, _arg1, _arg2, _arg3, _arg4, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_round_rect(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_round_rect(_canvas, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_arc(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_arc(_canvas, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_chord(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_chord(_canvas, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_pie(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_pie(_canvas, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_triangle(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_triangle(_canvas, _arg1, _arg2, _arg3, _arg4, _arg5, _arg6, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_polyline(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_polygon(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_box_array(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  def canvas_stroke_rect_array(_canvas, _arg1, _opts \\ []) do
    :erlang.nif_error(:nif_not_loaded)
  end

  # ------------------------
  # Fonts / Text
  # ------------------------
  def face_load(_path), do: :erlang.nif_error(:nif_not_loaded)
  def face_design_metrics(_face), do: :erlang.nif_error(:nif_not_loaded)
  def face_get_feature_tags(_face), do: :erlang.nif_error(:nif_not_loaded)

  def font_create(_face, _size), do: :erlang.nif_error(:nif_not_loaded)
  def font_create_with_features(_face, _size, _features), do: :erlang.nif_error(:nif_not_loaded)
  def font_metrics(_font), do: :erlang.nif_error(:nif_not_loaded)
  def font_shape(_font, _gb), do: :erlang.nif_error(:nif_not_loaded)
  def font_get_matrix(_font), do: :erlang.nif_error(:nif_not_loaded)

  def font_get_text_metrics(_font, _gb), do: :erlang.nif_error(:nif_not_loaded)
  def font_get_glyph_run_outlines(_font, _gb, _m, _path), do: :erlang.nif_error(:nif_not_loaded)

  def font_get_glyph_outlines(_font, _glyph_id, _matrix, _path),
    do: :erlang.nif_error(:nif_not_loaded)

  def font_get_glyph_bounds(_font, _glyph_ids),
    do: :erlang.nif_error(:nif_not_loaded)

  def font_get_feature_settings(_font), do: :erlang.nif_error(:nif_not_loaded)

  def canvas_fill_utf8_text(_canvas, _font, _x, _y, _text),
    do: :erlang.nif_error(:nif_not_loaded)

  def canvas_fill_utf8_text(_canvas, _font, _x, _y, _text, _opts),
    do: :erlang.nif_error(:nif_not_loaded)

  def canvas_stroke_utf8_text(_canvas, _font, _x, _y, _text),
    do: :erlang.nif_error(:nif_not_loaded)

  def canvas_stroke_utf8_text(_canvas, _font, _x, _y, _text, _opts),
    do: :erlang.nif_error(:nif_not_loaded)

  def glyph_buffer_new(), do: :erlang.nif_error(:nif_not_loaded)
  def glyph_buffer_set_utf8_text(_gb, _text), do: :erlang.nif_error(:nif_not_loaded)
  def glyph_run_new(_gb), do: :erlang.nif_error(:nif_not_loaded)

  def fill_glyph_run(_c, _font, _x, _y, _glyph_run),
    do: :erlang.nif_error(:nif_not_loaded)

  def fill_glyph_run(_c, _font, _x, _y, _glyph_run, _opts),
    do: :erlang.nif_error(:nif_not_loaded)

  def stroke_glyph_run(_c, _font, _x, _y, _glyph_run),
    do: :erlang.nif_error(:nif_not_loaded)

  def stroke_glyph_run(_c, _font, _x, _y, _glyph_run, _opts),
    do: :erlang.nif_error(:nif_not_loaded)

  def glyph_run_info(_gb), do: :erlang.nif_error(:nif_not_loaded)
  def glyph_run_inspect(_gb), do: :erlang.nif_error(:nif_not_loaded)
  def glyph_run_slice(_gb, _start, _count), do: :erlang.nif_error(:nif_not_loaded)
end
