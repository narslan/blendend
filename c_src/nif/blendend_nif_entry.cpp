#include "../canvas/canvas.h"
#include "../geometries/matrix2d.h"
#include "../geometries/path.h"
#include "../images/image.h"
#include "../nif/nif_templates.h"
#include "../styles/styles.h"
#include "../text/font.h"
#include "../text/glyph_buffer.h"
#include "../text/glyph_run.h"
#include "../rand/rand.h"

#include <cstring>

#define MAKE_DRAW_NIF(Name, ShapeT, Method) \
  ERL_NIF_TERM Name(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) \
  { \
    return draw_shape_template<ShapeT>(env, argc, argv, &BLContext::Method); \
  }
#define MAKE_TERM(Name) ERL_NIF_TERM Name(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);

#define MAKE_DRAW_TEXT(Name) \
  ERL_NIF_TERM canvas_##Name(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) \
  { \
    using FnType = \
        BLResult (BLContext::*)(const BLPoint&, const BLFontCore&, const BLStringView&) noexcept; \
    return draw_text_or_glyph_template<FnType>( \
        env, argc, argv, static_cast<FnType>(&BLContext::Name)); \
  }

#define MAKE_DRAW_GLYPH(Name) \
  ERL_NIF_TERM Name(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) \
  { \
    using FnType = \
        BLResult (BLContext::*)(const BLPoint&, const BLFontCore&, const BLGlyphRun&) noexcept; \
    return draw_text_or_glyph_template<FnType>( \
        env, argc, argv, static_cast<FnType>(&BLContext::Name)); \
  }

static int load(ErlNifEnv* env, void**, ERL_NIF_TERM)
{

  if(NifResource<Canvas>::open(env, "Elixir.Blendend.Native", "CanvasRes") < 0)
    return -1;
  if(NifResource<Image>::open(env, "Elixir.Blendend.Native", "ImageRes") < 0)
    return -1;
  if(NifResource<Path>::open(env, "Elixir.Blendend.Native", "Path") < 0)
    return -1;
  if(NifResource<Matrix2D>::open(env, "Elixir.Blendend.Native", "Matrix2D") < 0)
    return -1;
  if(NifResource<Color>::open(env, "Elixir.Blendend.Native", "ColorRes") < 0)
    return -1;
  if(NifResource<Gradient>::open(env, "Elixir.Blendend.Native", "GradientRes") < 0)
    return -1;
  if(NifResource<Pattern>::open(env, "Elixir.Blendend.Native", "PatternRes") < 0)
    return -1;
  if(NifResource<FontFace>::open(env, "Elixir.Blendend.Native", "FontfaceRes") < 0)
    return -1;
  if(NifResource<Font>::open(env, "Elixir.Blendend.Native", "FontRes") < 0)
    return -1;
  if(NifResource<GlyphBuffer>::open(env, "Elixir.Blendend.Native", "GlyphBufferRes") < 0)
    return -1;
  if(NifResource<GlyphRun>::open(env, "Elixir.Blendend.Native", "GlyphRun") < 0)
    return -1;
  if(NifResource<RandState>::open(env, "Elixir.Blendend.Native", "RandRes") < 0)
    return -1;

  return 0;
}

// Canvas
MAKE_TERM(canvas_new)
MAKE_TERM(canvas_save_state)
MAKE_TERM(canvas_restore_state)
// Canvas transform
MAKE_TERM(canvas_set_transform)
MAKE_TERM(canvas_reset_transform)

MAKE_TERM(canvas_translate)
MAKE_TERM(canvas_post_translate)
MAKE_TERM(canvas_scale)
MAKE_TERM(canvas_rotate)
MAKE_TERM(canvas_rotate_at)
MAKE_TERM(canvas_post_rotate)
MAKE_TERM(canvas_post_rotate_at)
MAKE_TERM(canvas_skew)

MAKE_TERM(canvas_apply_transform)
MAKE_TERM(canvas_user_transform)
MAKE_TERM(canvas_set_fill_rule)
MAKE_TERM(canvas_clear)
MAKE_TERM(canvas_clip_to_rect)
MAKE_TERM(canvas_blit_image)
MAKE_TERM(canvas_blit_image_scaled)
MAKE_TERM(canvas_fill_mask)
MAKE_TERM(canvas_blur_path)

MAKE_TERM(canvas_to_png_base64)
MAKE_TERM(canvas_to_png)
MAKE_TERM(canvas_to_qoi)

// Image
MAKE_TERM(image_size)
MAKE_TERM(image_read_from_file)
MAKE_TERM(image_read_from_data)
MAKE_TERM(image_read_mask_from_data)
MAKE_TERM(image_decode_qoi)
MAKE_TERM(image_blur)

// Rand
MAKE_TERM(rand_new)
MAKE_TERM(rand_normal_batch)

// Styles
MAKE_TERM(color)
MAKE_TERM(color_components)
MAKE_TERM(gradient_linear)
MAKE_TERM(gradient_radial)
MAKE_TERM(gradient_conic)
MAKE_TERM(gradient_add_stop)
MAKE_TERM(gradient_set_extend)
MAKE_TERM(gradient_set_transform)
MAKE_TERM(gradient_reset_transform)
MAKE_TERM(pattern_create)
MAKE_TERM(pattern_set_extend)
MAKE_TERM(pattern_set_transform)
MAKE_TERM(pattern_reset_transform)

//Geometries
MAKE_TERM(path_new)
MAKE_TERM(path_set_vertex_at)
MAKE_TERM(path_vertex_count)
MAKE_TERM(path_vertex_at)
MAKE_TERM(path_debug_dump)
MAKE_TERM(path_shrink)
MAKE_TERM(path_move_to)
MAKE_TERM(path_line_to)
MAKE_TERM(path_quad_to)
MAKE_TERM(path_cubic_to)
MAKE_TERM(path_conic_to)
MAKE_TERM(path_smooth_quad_to)
MAKE_TERM(path_smooth_cubic_to)
MAKE_TERM(path_arc_to)
MAKE_TERM(path_elliptic_arc_to)
MAKE_TERM(path_arc_quadrant_to)

MAKE_TERM(path_add_box)
MAKE_TERM(path_add_rect)
MAKE_TERM(path_add_circle)
MAKE_TERM(path_add_ellipse)
MAKE_TERM(path_add_round_rect)
MAKE_TERM(path_add_arc)
MAKE_TERM(path_add_chord)
MAKE_TERM(path_add_line)
MAKE_TERM(path_add_triangle)
MAKE_TERM(path_add_polyline)
MAKE_TERM(path_add_polygon)
MAKE_TERM(path_add_path)
MAKE_TERM(path_add_path_transform)
MAKE_TERM(path_add_stroked_path)
MAKE_TERM(path_translate)
MAKE_TERM(path_transform)
MAKE_TERM(path_close)
MAKE_TERM(path_hit_test)
MAKE_TERM(path_clear)
MAKE_TERM(path_equals)
MAKE_TERM(path_fit_to)
MAKE_TERM(path_flatten)

MAKE_TERM(canvas_fill_path)
MAKE_TERM(canvas_stroke_path)

MAKE_TERM(matrix2d_new)
MAKE_TERM(matrix2d_identity)

MAKE_TERM(matrix2d_to_list)
MAKE_TERM(matrix2d_translate)
MAKE_TERM(matrix2d_post_translate)
MAKE_TERM(matrix2d_scale)
MAKE_TERM(matrix2d_post_scale)
MAKE_TERM(matrix2d_skew)
MAKE_TERM(matrix2d_post_skew)
MAKE_TERM(matrix2d_rotate)
MAKE_TERM(matrix2d_rotate_at)
MAKE_TERM(matrix2d_post_rotate)
MAKE_TERM(matrix2d_transform)
MAKE_TERM(matrix2d_post_transform)
MAKE_TERM(matrix2d_invert)
MAKE_TERM(matrix2d_map_point)
MAKE_TERM(matrix2d_map_vector)
MAKE_TERM(matrix2d_make_sin_cos)
// Fill Geometry
MAKE_DRAW_NIF(canvas_fill_box, BLBox, fill_box)
MAKE_DRAW_NIF(canvas_fill_rect, BLRect, fill_rect)
MAKE_DRAW_NIF(canvas_fill_circle, BLCircle, fill_circle)
MAKE_DRAW_NIF(canvas_fill_ellipse, BLEllipse, fill_ellipse)
MAKE_DRAW_NIF(canvas_fill_round_rect, BLRoundRect, fill_round_rect)
MAKE_DRAW_NIF(canvas_fill_chord, BLArc, fill_chord)
MAKE_DRAW_NIF(canvas_fill_pie, BLArc, fill_pie)
MAKE_DRAW_NIF(canvas_fill_triangle, BLTriangle, fill_triangle)
MAKE_DRAW_NIF(canvas_fill_polygon, BLArrayView<BLPoint>, fill_polygon)
MAKE_DRAW_NIF(canvas_fill_box_array, BLArrayView<BLBox>, fill_box_array)
MAKE_DRAW_NIF(canvas_fill_rect_array, BLArrayView<BLRect>, fill_rect_array)

// Stroke Geometry
MAKE_DRAW_NIF(canvas_stroke_rect, BLRect, stroke_rect)
MAKE_DRAW_NIF(canvas_stroke_box, BLBox, stroke_box)
MAKE_DRAW_NIF(canvas_stroke_line, BLLine, stroke_line)
MAKE_DRAW_NIF(canvas_stroke_circle, BLCircle, stroke_circle)
MAKE_DRAW_NIF(canvas_stroke_ellipse, BLEllipse, stroke_ellipse)
MAKE_DRAW_NIF(canvas_stroke_round_rect, BLRoundRect, stroke_round_rect)
MAKE_DRAW_NIF(canvas_stroke_arc, BLArc, stroke_arc)
MAKE_DRAW_NIF(canvas_stroke_chord, BLArc, stroke_chord)
MAKE_DRAW_NIF(canvas_stroke_pie, BLArc, stroke_pie)
MAKE_DRAW_NIF(canvas_stroke_triangle, BLTriangle, stroke_triangle)
MAKE_DRAW_NIF(canvas_stroke_polyline, BLArrayView<BLPoint>, stroke_polyline)
MAKE_DRAW_NIF(canvas_stroke_polygon, BLArrayView<BLPoint>, stroke_polygon)
MAKE_DRAW_NIF(canvas_stroke_box_array, BLArrayView<BLBox>, stroke_box_array)
MAKE_DRAW_NIF(canvas_stroke_rect_array, BLArrayView<BLRect>, stroke_rect_array)

// Text and Font Handling
MAKE_TERM(face_load)
MAKE_TERM(face_design_metrics)
MAKE_TERM(face_get_feature_tags)

MAKE_TERM(font_create)
MAKE_TERM(font_create_with_features)
MAKE_TERM(font_metrics)
MAKE_TERM(font_shape)
MAKE_TERM(font_get_matrix)
MAKE_TERM(font_get_text_metrics)
MAKE_TERM(font_get_glyph_run_outlines)
MAKE_TERM(font_get_glyph_outlines)
MAKE_TERM(font_get_glyph_bounds)
MAKE_TERM(font_get_feature_settings)

MAKE_TERM(glyph_buffer_new)
MAKE_TERM(glyph_buffer_set_utf8_text)
MAKE_TERM(glyph_run_new)
MAKE_TERM(glyph_run_info)
MAKE_TERM(glyph_run_inspect)
MAKE_TERM(glyph_run_slice)

MAKE_DRAW_TEXT(fill_utf8_text)
MAKE_DRAW_TEXT(stroke_utf8_text)
MAKE_DRAW_GLYPH(fill_glyph_run)
MAKE_DRAW_GLYPH(stroke_glyph_run)

// NIF Lists: name, arity, flags
#define NIF_LIST(X) \
  /* Canvas */ \
  X(canvas_new, 2, 0) \
  X(canvas_clear, 2, 0) \
  /* Canvas state */ \
  X(canvas_save_state, 1, 0) \
  X(canvas_restore_state, 1, 0) \
  /* Transform */ \
  X(canvas_set_transform, 2, 0) \
  X(canvas_reset_transform, 1, 0) \
  X(canvas_apply_transform, 2, 0) \
  X(canvas_user_transform, 1, 0) \
  X(canvas_translate, 3, 0) \
  X(canvas_post_translate, 3, 0) \
  X(canvas_scale, 3, 0) \
  X(canvas_rotate, 2, 0) \
  X(canvas_rotate_at, 4, 0) \
  X(canvas_post_rotate, 2, 0) \
  X(canvas_post_rotate_at, 4, 0) \
  X(canvas_skew, 3, 0) \
  X(canvas_clip_to_rect, 5, 0) \
  X(canvas_fill_mask, 4, 0) \
  X(canvas_fill_mask, 5, 0) \
  X(canvas_blur_path, 3, ERL_NIF_DIRTY_JOB_CPU_BOUND) \
  X(canvas_blur_path, 4, ERL_NIF_DIRTY_JOB_CPU_BOUND) \
  X(canvas_set_fill_rule, 2, 0) \
  X(canvas_blit_image, 4, 0) \
  X(canvas_blit_image_scaled, 6, 0) \
  X(canvas_to_png_base64, 1, ERL_NIF_DIRTY_JOB_CPU_BOUND) \
  X(canvas_to_png, 1, ERL_NIF_DIRTY_JOB_CPU_BOUND) \
  X(canvas_to_qoi, 1, ERL_NIF_DIRTY_JOB_CPU_BOUND) \
  X(canvas_fill_path, 2, 0) \
  X(canvas_fill_path, 3, 0) \
  X(canvas_stroke_path, 2, 0) \
  X(canvas_stroke_path, 3, 0) \
  /* Image */ \
  X(image_size, 1, 0) \
  X(image_read_from_data, 1, ERL_NIF_DIRTY_JOB_CPU_BOUND) \
  X(image_read_mask_from_data, 2, ERL_NIF_DIRTY_JOB_CPU_BOUND) \
  X(image_decode_qoi, 1, ERL_NIF_DIRTY_JOB_CPU_BOUND) \
  X(image_blur, 2, ERL_NIF_DIRTY_JOB_CPU_BOUND) \
  /* Rand */ \
  X(rand_new, 1, 0) \
  X(rand_normal_batch, 2, 0) \
  /* Styles */ \
  X(color, 4, 0) \
  X(color_components, 1, 0) \
  X(gradient_linear, 4, 0) \
  X(gradient_radial, 6, 0) \
  X(gradient_conic, 3, 0) \
  X(gradient_add_stop, 3, 0) \
  X(gradient_set_extend, 2, 0) \
  X(gradient_set_transform, 2, 0) \
  X(gradient_reset_transform, 1, 0) \
  X(pattern_create, 1, 0) \
  X(pattern_set_transform, 2, 0) \
  X(pattern_reset_transform, 1, 0) \
  X(pattern_set_extend, 2, 0) \
  /* Geometries */ \
  X(path_new, 0, 0) \
  X(path_set_vertex_at, 5, 0) \
  X(path_vertex_count, 1, 0) \
  X(path_move_to, 3, 0) \
  X(path_line_to, 3, 0) \
  X(path_quad_to, 5, 0) \
  X(path_cubic_to, 7, 0) \
  X(path_arc_quadrant_to, 5, 0) \
  X(path_conic_to, 6, 0) \
  X(path_smooth_quad_to, 3, 0) \
  X(path_smooth_cubic_to, 5, 0) \
  X(path_arc_to, 8, 0) \
  X(path_elliptic_arc_to, 8, 0) \
  X(path_add_box, 7, 0) \
  X(path_add_rect, 7, 0) \
  X(path_add_circle, 6, 0) \
  X(path_add_ellipse, 7, 0) \
  X(path_add_round_rect, 9, 0) \
  X(path_add_arc, 9, 0) \
  X(path_add_chord, 9, 0) \
  X(path_add_line, 7, 0) \
  X(path_add_triangle, 9, 0) \
  X(path_add_polyline, 4, 0) \
  X(path_add_polygon, 4, 0) \
  X(path_add_path, 2, 0) \
  X(path_add_path_transform, 3, 0) \
  X(path_add_stroked_path, 3, 0) \
  X(path_add_stroked_path, 4, 0) \
  X(path_add_stroked_path, 5, 0) \
  X(path_translate, 3, 0) \
  X(path_translate, 4, 0) \
  X(path_transform, 2, 0) \
  X(path_transform, 3, 0) \
  X(path_vertex_at, 2, 0) \
  X(path_shrink, 1, 0) \
  X(path_debug_dump, 1, 0) \
  X(path_close, 1, 0) \
  X(path_hit_test, 3, 0) \
  X(path_hit_test, 4, 0) \
  X(path_clear, 1, 0) \
  X(path_equals, 2, 0) \
  X(path_fit_to, 2, 0) \
  X(path_flatten, 2, 0) \
  /* Matrix */ \
  X(matrix2d_new, 1, 0) \
  X(matrix2d_identity, 0, 0) \
  X(matrix2d_to_list, 1, 0) \
  X(matrix2d_translate, 3, 0) \
  X(matrix2d_post_translate, 3, 0) \
  X(matrix2d_skew, 3, 0) \
  X(matrix2d_scale, 3, 0) \
  X(matrix2d_post_scale, 3, 0) \
  X(matrix2d_post_skew, 3, 0) \
  X(matrix2d_rotate, 2, 0) \
  X(matrix2d_rotate_at, 4, 0) \
  X(matrix2d_post_rotate, 4, 0) \
  X(matrix2d_transform, 2, 0) \
  X(matrix2d_post_transform, 2, 0) \
  X(matrix2d_invert, 1, 0) \
  X(matrix2d_map_point, 3, 0) \
  X(matrix2d_map_vector, 3, 0) \
  X(matrix2d_make_sin_cos, 4, 0) \
  /* Canvas fill */ \
  X(canvas_fill_box, 5, 0) \
  X(canvas_fill_box, 6, 0) \
  X(canvas_fill_rect, 5, 0) \
  X(canvas_fill_rect, 6, 0) \
  X(canvas_fill_circle, 4, 0) \
  X(canvas_fill_circle, 5, 0) \
  X(canvas_fill_ellipse, 5, 0) \
  X(canvas_fill_ellipse, 6, 0) \
  X(canvas_fill_round_rect, 7, 0) \
  X(canvas_fill_round_rect, 8, 0) \
  X(canvas_fill_chord, 7, 0) \
  X(canvas_fill_chord, 8, 0) \
  X(canvas_fill_pie, 7, 0) \
  X(canvas_fill_pie, 8, 0) \
  X(canvas_fill_triangle, 7, 0) \
  X(canvas_fill_triangle, 8, 0) \
  X(canvas_fill_polygon, 2, 0) \
  X(canvas_fill_polygon, 3, 0) \
  X(canvas_fill_box_array, 2, 0) \
  X(canvas_fill_box_array, 3, 0) \
  X(canvas_fill_rect_array, 2, 0) \
  X(canvas_fill_rect_array, 3, 0) \
  /* Canvas stroke */ \
  X(canvas_stroke_box, 5, 0) \
  X(canvas_stroke_box, 6, 0) \
  X(canvas_stroke_rect, 5, 0) \
  X(canvas_stroke_rect, 6, 0) \
  X(canvas_stroke_circle, 4, 0) \
  X(canvas_stroke_circle, 5, 0) \
  X(canvas_stroke_line, 5, 0) \
  X(canvas_stroke_line, 6, 0) \
  X(canvas_stroke_ellipse, 5, 0) \
  X(canvas_stroke_ellipse, 6, 0) \
  X(canvas_stroke_round_rect, 7, 0) \
  X(canvas_stroke_round_rect, 8, 0) \
  X(canvas_stroke_arc, 7, 0) \
  X(canvas_stroke_arc, 8, 0) \
  X(canvas_stroke_chord, 7, 0) \
  X(canvas_stroke_chord, 8, 0) \
  X(canvas_stroke_pie, 7, 0) \
  X(canvas_stroke_pie, 8, 0) \
  X(canvas_stroke_triangle, 7, 0) \
  X(canvas_stroke_triangle, 8, 0) \
  X(canvas_stroke_polyline, 2, 0) \
  X(canvas_stroke_polyline, 3, 0) \
  X(canvas_stroke_polygon, 2, 0) \
  X(canvas_stroke_polygon, 3, 0) \
  X(canvas_stroke_box_array, 2, 0) \
  X(canvas_stroke_box_array, 3, 0) \
  X(canvas_stroke_rect_array, 2, 0) \
  X(canvas_stroke_rect_array, 3, 0) \
  /* Font/Text */ \
  X(font_create, 2, 0) \
  X(font_create_with_features, 3, 0) \
  X(face_load, 1, 0) \
  X(face_design_metrics, 1, 0) \
  X(face_get_feature_tags, 1, 0) \
  X(font_metrics, 1, 0) \
  X(font_shape, 2, 0) \
  X(font_get_matrix, 1, 0) \
  X(font_get_text_metrics, 2, 0) \
  X(font_get_glyph_run_outlines, 4, 0) \
  X(font_get_glyph_outlines, 4, 0) \
  X(font_get_glyph_bounds, 2, 0) \
  X(font_get_feature_settings, 1, 0) \
  X(canvas_fill_utf8_text, 5, 0) \
  X(canvas_fill_utf8_text, 6, 0) \
  X(canvas_stroke_utf8_text, 5, 0) \
  X(canvas_stroke_utf8_text, 6, 0) \
  X(glyph_buffer_new, 0, 0) \
  X(glyph_run_new, 1, 0) \
  X(glyph_buffer_set_utf8_text, 2, 0) \
  X(fill_glyph_run, 5, 0) \
  X(fill_glyph_run, 6, 0) \
  X(stroke_glyph_run, 5, 0) \
  X(stroke_glyph_run, 6, 0) \
  X(glyph_run_info, 1, 0) \
  X(glyph_run_inspect, 1, 0) \
  X(glyph_run_slice, 3, 0)

#define MAKE_NIF(name, arity, flags) {#name, arity, name, flags},
static ErlNifFunc nif_funcs[] = {NIF_LIST(MAKE_NIF)};
#undef MAKE_NIF

ERL_NIF_INIT(Elixir.Blendend.Native, nif_funcs, load, NULL, NULL, NULL)
