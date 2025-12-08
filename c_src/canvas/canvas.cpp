#include "canvas.h"
#include "../geometries/matrix2d.h"
#include "../images/image.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"
#include "../styles/styles.h"

#include <blend2d/blend2d.h>
#include <blend2d/core/format.h>
#include <unordered_map>

// Canvas.new(width, height)
ERL_NIF_TERM canvas_new(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int w, h;

  if(argc != 2 || !enif_get_int(env, argv[0], &w) || !enif_get_int(env, argv[1], &h)) {
    return make_result_error(env, "canvas_dimensions_must_be_integer");
  }

  auto canvas = NifResource<Canvas>::alloc();

  BLResult r = canvas->img.create(w, h, BL_FORMAT_PRGB32);
  if(r != BL_SUCCESS) {
    canvas->destroy();
    return make_result_error(env, "canvas_image_create_failed");
  }

  // 2) Begin a context on that image
  BLContextCreateInfo ci{};

  BLResult rc = canvas->ctx.begin(canvas->img, &ci);
  if(rc != BL_SUCCESS) {
    canvas->destroy();
    return make_result_error(env, "canvas_context_begin_failed");
  }

  ERL_NIF_TERM term = NifResource<Canvas>::make(env, canvas);
  return make_result_ok(env, term);
}

ERL_NIF_TERM canvas_clear(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc < 1)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(!canvas)
    return make_result_error(env, "canvas_clear_invalid_canvas");

  Style style{};
  parse_style(env, argv, argc, 1, &style);

  if(!style.has_fill()) {
    canvas->ctx.clear_all();
    canvas->ctx.flush(BL_CONTEXT_FLUSH_SYNC);
    return enif_make_atom(env, "ok");
  }

  canvas->ctx.save();
  style.apply(&canvas->ctx);
  canvas->ctx.fill_all();
  canvas->ctx.restore();

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_set_comp_op(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "canvas_set_comp_op_invalid_canvas");
  }

  char op[32];
  if(!enif_get_atom(env, argv[1], op, sizeof(op), ERL_NIF_UTF8)) {
    return make_result_error(env, "canvas_set_comp_op_invalid_atom");
  }

  static const std::unordered_map<std::string, BLCompOp> comp_map = {
      {"src_over", BL_COMP_OP_SRC_OVER},
      {"src_copy", BL_COMP_OP_SRC_COPY},
      {"src_in", BL_COMP_OP_SRC_IN},
      {"src_out", BL_COMP_OP_SRC_OUT},
      {"src_atop", BL_COMP_OP_SRC_ATOP},
      {"dst_over", BL_COMP_OP_DST_OVER},
      {"dst_copy", BL_COMP_OP_DST_COPY},
      {"dst_in", BL_COMP_OP_DST_IN},
      {"dst_out", BL_COMP_OP_DST_OUT},
      {"dst_atop", BL_COMP_OP_DST_ATOP},
      {"difference", BL_COMP_OP_DIFFERENCE},
      {"multiply", BL_COMP_OP_MULTIPLY},
      {"screen", BL_COMP_OP_SCREEN},
      {"overlay", BL_COMP_OP_OVERLAY},
      {"xor", BL_COMP_OP_XOR},
      {"clear", BL_COMP_OP_CLEAR},
      {"plus", BL_COMP_OP_PLUS},
      {"minus", BL_COMP_OP_MINUS},
      {"modulate", BL_COMP_OP_MODULATE},
      {"darken", BL_COMP_OP_DARKEN},
      {"lighten", BL_COMP_OP_LIGHTEN},
      {"color_dodge", BL_COMP_OP_COLOR_DODGE},
      {"color_burn", BL_COMP_OP_COLOR_BURN},
      {"linear_burn", BL_COMP_OP_LINEAR_BURN},
      {"pin_light", BL_COMP_OP_PIN_LIGHT},
      {"hard_light", BL_COMP_OP_HARD_LIGHT},
      {"soft_light", BL_COMP_OP_SOFT_LIGHT},
      {"exclusion", BL_COMP_OP_EXCLUSION}};

  auto it = comp_map.find(std::string(op));
  if(it == comp_map.end()) {
    return make_result_error(env, "canvas_set_comp_op_invalid_mode");
  }

  BLResult r = canvas->ctx.set_comp_op(it->second);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_set_comp_op_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_set_global_alpha(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr)
    return make_result_error(env, "canvas_set_global_alpha_invalid_canvas");

  double alpha;
  if(!enif_get_double(env, argv[1], &alpha))
    return make_result_error(env, "canvas_set_global_alpha_invalid_alpha");

  BLResult r = canvas->ctx.set_global_alpha(alpha);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_set_global_alpha_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_set_style_alpha(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr)
    return make_result_error(env, "canvas_set_style_alpha_invalid_canvas");

  char slot_atom[16];
  if(!enif_get_atom(env, argv[1], slot_atom, sizeof(slot_atom), ERL_NIF_UTF8))
    return make_result_error(env, "canvas_set_style_alpha_invalid_slot");

  static const std::unordered_map<std::string, BLContextStyleSlot> slot_map = {
      {"fill", BL_CONTEXT_STYLE_SLOT_FILL},
      {"stroke", BL_CONTEXT_STYLE_SLOT_STROKE},
  };

  auto it = slot_map.find(std::string(slot_atom));
  if(it == slot_map.end())
    return make_result_error(env, "canvas_set_style_alpha_invalid_slot");

  double alpha;
  if(!enif_get_double(env, argv[2], &alpha))
    return make_result_error(env, "canvas_set_style_alpha_invalid_alpha");

  BLResult r = BL_SUCCESS;
  if(it->second == BL_CONTEXT_STYLE_SLOT_FILL) {
    r = canvas->ctx.set_fill_alpha(alpha);
  }
  else if(it->second == BL_CONTEXT_STYLE_SLOT_STROKE) {
    r = canvas->ctx.set_stroke_alpha(alpha);
  }
  else {
    r = canvas->ctx.set_style_alpha(it->second, alpha);
  }

  if(r != BL_SUCCESS) {
    return make_result_error(env, "canvas_set_style_alpha_failed");
  }

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_disable_style(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr)
    return make_result_error(env, "canvas_disable_style_invalid_canvas");

  char slot_atom[16];
  if(!enif_get_atom(env, argv[1], slot_atom, sizeof(slot_atom), ERL_NIF_UTF8))
    return make_result_error(env, "canvas_disable_style_invalid_slot");

  static const std::unordered_map<std::string, BLContextStyleSlot> slot_map = {
      {"fill", BL_CONTEXT_STYLE_SLOT_FILL},
      {"stroke", BL_CONTEXT_STYLE_SLOT_STROKE},
  };

  auto it = slot_map.find(std::string(slot_atom));
  if(it == slot_map.end())
    return make_result_error(env, "canvas_disable_style_invalid_slot");

  BLResult r = canvas->ctx.disable_style(it->second);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_disable_style_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_save_state(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  Canvas* canvas = NifResource<Canvas>::get(env, argv[0]);
  if(!canvas)
    return make_result_error(env, "canvas_save_state_invalid_canvas");

  BLResult r = canvas->ctx.save();
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_save_state_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_restore_state(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  Canvas* canvas = NifResource<Canvas>::get(env, argv[0]);
  if(!canvas)
    return make_result_error(env, "canvas_restore_state_invalid_canvas");

  BLResult r = canvas->ctx.restore();
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_restore_state_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_set_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  Canvas* canvas = NifResource<Canvas>::get(env, argv[0]);
  Matrix2D* mat = NifResource<Matrix2D>::get(env, argv[1]);
  if(!canvas || !mat)
    return make_result_error(env, "canvas_set_transform_invalid_args");

  BLResult r = canvas->ctx.set_transform(mat->value);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_set_transform_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_reset_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  Canvas* canvas = NifResource<Canvas>::get(env, argv[0]);
  if(!canvas)
    return make_result_error(env, "canvas_reset_transform_invalid_canvas");

  BLResult r = canvas->ctx.reset_transform();
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_reset_transform_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_set_stroke_width(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  Canvas* canvas = NifResource<Canvas>::get(env, argv[0]);
  double width;

  if(!canvas)
    return make_result_error(env, "canvas_set_stroke_width_invalid_canvas");

  if(!enif_get_double(env, argv[1], &width)) {
    return make_result_error(env, "canvas_set_stroke_width_invalid_width");
  }

  BLResult r = canvas->ctx.set_stroke_width(width);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_set_stroke_width_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_set_stroke_style(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  Canvas* canvas = NifResource<Canvas>::get(env, argv[0]);
  if(!canvas)
    return make_result_error(env, "canvas_set_stroke_style_invalid_canvas");

  // Try Color
  Color* color = NifResource<Color>::get(env, argv[1]);
  if(color) {
    BLResult r = canvas->ctx.set_stroke_style(color->value);
    if(r != BL_SUCCESS)
      return make_result_error(env, "canvas_set_stroke_style_failed");
    return enif_make_atom(env, "ok");
  }

  // Try Gradient
  Gradient* grad = NifResource<Gradient>::get(env, argv[1]);
  if(grad) {
    BLResult r = canvas->ctx.set_stroke_style(grad->value);
    if(r != BL_SUCCESS)
      return make_result_error(env, "canvas_set_stroke_style_failed");
    return enif_make_atom(env, "ok");
  }

  // Try Pattern
  Pattern* pattern = NifResource<Pattern>::get(env, argv[1]);
  if(pattern) {
    BLResult r = canvas->ctx.set_stroke_style(pattern->value);
    if(r != BL_SUCCESS)
      return make_result_error(env, "canvas_set_stroke_style_failed");
    return enif_make_atom(env, "ok");
  }

  return make_result_error(env, "canvas_set_stroke_style_invalid_style");
}

ERL_NIF_TERM canvas_set_stroke_join(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  Canvas* canvas = NifResource<Canvas>::get(env, argv[0]);
  if(!canvas)
    return make_result_error(env, "canvas_set_stroke_join_invalid_canvas");

  char join[32];
  if(!enif_get_atom(env, argv[1], join, sizeof(join), ERL_NIF_UTF8)) {
    return make_result_error(env, "canvas_set_stroke_join_invalid_atom");
  }

  static const std::unordered_map<std::string, BLStrokeJoin> join_map = {
      {"miter_clip", BL_STROKE_JOIN_MITER_CLIP},
      {"round", BL_STROKE_JOIN_ROUND},
      {"bevel", BL_STROKE_JOIN_BEVEL},
      {"miter_bevel", BL_STROKE_JOIN_MITER_BEVEL},
      {"miter_round", BL_STROKE_JOIN_MITER_ROUND}};

  auto it = join_map.find(std::string(join));
  if(it == join_map.end()) {
    return make_result_error(env, "canvas_set_stroke_join_invalid_value");
  }

  BLResult r = canvas->ctx.set_stroke_join(it->second);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_set_stroke_join_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_set_fill_style(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  Canvas* canvas = NifResource<Canvas>::get(env, argv[0]);
  if(!canvas)
    return make_result_error(env, "canvas_set_fill_style_invalid_canvas");

  if(auto color = NifResource<Color>::get(env, argv[1])) {
    if(canvas->ctx.set_fill_style(color->value) != BL_SUCCESS)
      return make_result_error(env, "canvas_set_fill_style_failed");
    return enif_make_atom(env, "ok");
  }

  if(auto grad = NifResource<Gradient>::get(env, argv[1])) {
    if(canvas->ctx.set_fill_style(grad->value) != BL_SUCCESS)
      return make_result_error(env, "canvas_set_fill_style_failed");
    return enif_make_atom(env, "ok");
  }

  if(auto pat = NifResource<Pattern>::get(env, argv[1])) {
    if(canvas->ctx.set_fill_style(pat->value) != BL_SUCCESS)
      return make_result_error(env, "canvas_set_fill_style_failed");
    return enif_make_atom(env, "ok");
  }

  return make_result_error(env, "canvas_set_fill_style_invalid_style");
}

ERL_NIF_TERM canvas_translate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  double x, y;

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "canvas_translate_invalid_canvas");
  }

  if(!enif_get_double(env, argv[1], &x) || !enif_get_double(env, argv[2], &y)) {
    return make_result_error(env, "canvas_translate_invalid_args");
  }

  BLResult r = canvas->ctx.translate(x, y);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_translate_failed");

  return enif_make_atom(env, "ok");
}

// Post-translate the current transform (same as translate for Blend2D contexts).
ERL_NIF_TERM canvas_post_translate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  double x, y;

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "canvas_post_translate_invalid_canvas");
  }

  if(!enif_get_double(env, argv[1], &x) || !enif_get_double(env, argv[2], &y)) {
    return make_result_error(env, "canvas_post_translate_invalid_args");
  }

  BLResult r = canvas->ctx.translate(x, y);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_post_translate_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_scale(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  double sx, sy;

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "canvas_scale_invalid_canvas");
  }

  if(!enif_get_double(env, argv[1], &sx) || !enif_get_double(env, argv[2], &sy)) {
    return make_result_error(env, "canvas_scale_invalid_args");
  }

  BLResult r = canvas->ctx.scale(sx, sy);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_scale_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_rotate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  double angle;
  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "canvas_rotate_invalid_canvas");
  }

  if(!enif_get_double(env, argv[1], &angle)) {
    return make_result_error(env, "canvas_rotate_invalid_angle");
  }

  BLResult r = canvas->ctx.rotate(angle);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_rotate_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_rotate_at(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 4)
    return enif_make_badarg(env);

  double angle, cx, cy;
  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "canvas_rotate_at_invalid_canvas");
  }

  if(!enif_get_double(env, argv[1], &angle) || !enif_get_double(env, argv[2], &cx) ||
     !enif_get_double(env, argv[3], &cy)) {
    return make_result_error(env, "canvas_rotate_at_invalid_args");
  }

  BLResult r = canvas->ctx.rotate(angle, cx, cy);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_rotate_at_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_skew(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  double kx, ky;

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "canvas_skew_invalid_canvas");
  }

  if(!enif_get_double(env, argv[1], &kx) || !enif_get_double(env, argv[2], &ky)) {
    return make_result_error(env, "canvas_skew_invalid_args");
  }

  BLResult r = canvas->ctx.skew(kx, ky);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_skew_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_post_rotate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  double angle;
  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "canvas_post_rotate_invalid_canvas");
  }

  if(!enif_get_double(env, argv[1], &angle)) {
    return make_result_error(env, "canvas_post_rotate_invalid_angle");
  }

  BLResult r = canvas->ctx.post_rotate(angle);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_post_rotate_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_post_rotate_at(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 4)
    return enif_make_badarg(env);

  double angle, cx, cy;
  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "canvas_post_rotate_at_invalid_canvas");
  }

  if(!enif_get_double(env, argv[1], &angle) || !enif_get_double(env, argv[2], &cx) ||
     !enif_get_double(env, argv[3], &cy)) {
    return make_result_error(env, "canvas_post_rotate_at_invalid_args");
  }

  BLResult r = canvas->ctx.post_rotate(angle, cx, cy);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_post_rotate_at_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_apply_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  Canvas* canvas = NifResource<Canvas>::get(env, argv[0]);
  Matrix2D* mat = NifResource<Matrix2D>::get(env, argv[1]);
  if(!canvas || !mat)
    return make_result_error(env, "canvas_apply_transform_invalid_args");

  BLResult res = canvas->ctx.apply_transform(mat->value);
  if(res != BL_SUCCESS)
    return make_result_error(env, "canvas_apply_transform_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_user_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  Canvas* canvas = NifResource<Canvas>::get(env, argv[0]);
  if(!canvas)
    return make_result_error(env, "canvas_user_transform_invalid_canvas");

  Matrix2D* mat = NifResource<Matrix2D>::alloc();
  if(!mat)
    return make_result_error(env, "canvas_user_transform_alloc_failed");

  mat->value = canvas->ctx.user_transform();

  return make_result_ok(env, NifResource<Matrix2D>::make(env, mat));
}

// Clipping & Masking

ERL_NIF_TERM canvas_clip_to_rect(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 5)
    return enif_make_badarg(env);

  double x, y, w, h;
  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "clip_to_rect_invalid_canvas");
  }

  if(!enif_get_double(env, argv[1], &x) || !enif_get_double(env, argv[2], &y) ||
     !enif_get_double(env, argv[3], &w) || !enif_get_double(env, argv[4], &h)) {
    return enif_make_badarg(env);
  }

  BLResult r = canvas->ctx.clip_to_rect(BLRect(x, y, w, h));
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_clip_to_rect_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_blit_image(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 4)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  auto image = NifResource<Image>::get(env, argv[1]);
  double x = 0.0, y = 0.0;

  if(!canvas || !image) {
    return make_result_error(env, "canvas_blit_image_invalid_args");
  }

  if(!enif_get_double(env, argv[2], &x) || !enif_get_double(env, argv[3], &y)) {
    return make_result_error(env, "canvas_blit_image_invalid_args");
  }

  BLResult r = canvas->ctx.blit_image(BLPoint(x, y), image->value);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_blit_image_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_blit_image_scaled(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 6)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  auto image = NifResource<Image>::get(env, argv[1]);
  double x = 0.0, y = 0.0, w = 0.0, h = 0.0;

  if(!canvas || !image) {
    return make_result_error(env, "canvas_blit_image_invalid_args");
  }

  if(!enif_get_double(env, argv[2], &x) || !enif_get_double(env, argv[3], &y) ||
     !enif_get_double(env, argv[4], &w) || !enif_get_double(env, argv[5], &h)) {
    return make_result_error(env, "canvas_blit_image_invalid_args");
  }

  BLResult r = canvas->ctx.blit_image(BLRect(x, y, w, h), image->value);
  if(r != BL_SUCCESS)
    return make_result_error(env, "canvas_blit_image_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_fill_mask(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc < 4)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "canvas_fill_mask_invalid_canvas");
  }

  auto image = NifResource<Image>::get(env, argv[1]);
  if(image == nullptr) {
    return make_result_error(env, "canvas_fill_mask_invalid_image");
  }

  double x = 0.0, y = 0.0;
  if(!enif_get_double(env, argv[2], &x) || !enif_get_double(env, argv[3], &y)) {
    return make_result_error(env, "canvas_fill_mask_invalid_args");
  }

  // Optional style at argv[4]
  Style style{};
  if(argc >= 5 && enif_is_list(env, argv[4])) {
    parse_style(env, argv, argc, 4, &style);
  }

  canvas->ctx.save();
  style.apply(&canvas->ctx);

  BLResult rc = canvas->ctx.fill_mask(BLPoint(x, y), image->value);

  canvas->ctx.restore();

  if(rc != BL_SUCCESS)
    return make_result_error(env, "fill_mask_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_set_fill_rule(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "set_fill_rule_invalid_canvas");
  }

  char atom[32];
  if(!enif_get_atom(env, argv[1], atom, sizeof(atom), ERL_NIF_UTF8)) {
    return make_result_error(env, "set_fill_rule_invalid_atom");
  }

  BLFillRule rule = BL_FILL_RULE_NON_ZERO;

  if(std::strcmp(atom, "non_zero") == 0 || std::strcmp(atom, "nonzero") == 0) {
    rule = BL_FILL_RULE_NON_ZERO;
  }
  else if(std::strcmp(atom, "even_odd") == 0 || std::strcmp(atom, "evenodd") == 0) {
    rule = BL_FILL_RULE_EVEN_ODD;
  }
  else {
    return make_result_error(env, "canvas_set_fill_rule_invalid_rule");
  }

  canvas->ctx.set_fill_rule(rule);
  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM canvas_to_png_base64(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "to_png_base64_invalid_canvas");
  }

  BLArray<uint8_t> pngData;
  BLImageCodec png;
  png.find_by_extension("png");

  canvas->ctx.end();
  BLResult result = canvas->img.write_to_data(pngData, png);
  if(result != BL_SUCCESS) {
    return make_result_error(env, "canvas_to_png_base64_failed");
  }

  static const char b64_table[] =
      "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";

  std::string b64;
  b64.reserve((pngData.size() + 2) / 3 * 4);

  const uint8_t* data = pngData.data();
  size_t len = pngData.size();

  for(size_t i = 0; i < len; i += 3) {
    int val = (data[i] << 16) + ((i + 1 < len) ? (data[i + 1] << 8) : 0) +
              ((i + 2 < len) ? data[i + 2] : 0);
    b64.push_back(b64_table[(val >> 18) & 0x3F]);
    b64.push_back(b64_table[(val >> 12) & 0x3F]);
    b64.push_back((i + 1 < len) ? b64_table[(val >> 6) & 0x3F] : '=');
    b64.push_back((i + 2 < len) ? b64_table[val & 0x3F] : '=');
  }

  ERL_NIF_TERM bin;
  unsigned char* buf = enif_make_new_binary(env, b64.size(), &bin);
  std::memcpy(buf, b64.data(), b64.size());

  return make_result_ok(env, bin);
}

ERL_NIF_TERM canvas_to_png(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "to_png_invalid_canvas");
  }

  canvas->ctx.flush(BL_CONTEXT_FLUSH_SYNC);

  BLArray<uint8_t> png_data;
  BLImageCodec png;
  png.find_by_extension("png");

  BLResult wr = canvas->img.write_to_data(png_data, png);
  if(wr != BL_SUCCESS) {
    return make_result_error(env, "canvas_to_png_failed");
  }

  ERL_NIF_TERM bin;
  unsigned char* buf = enif_make_new_binary(env, png_data.size(), &bin);
  if(png_data.size() > 0) {
    std::memcpy(buf, png_data.data(), png_data.size());
  }

  return make_result_ok(env, bin);
}

ERL_NIF_TERM canvas_to_qoi(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "to_qoi_invalid_canvas");
  }

  // Make sure everything is flushed from the context to the image
  canvas->ctx.flush(BL_CONTEXT_FLUSH_SYNC);

  BLArray<uint8_t> qoi_data;
  BLImageCodec qoi;

  qoi.find_by_extension("qoi");

  // If QOI support isn't compiled in, this will fail.
  if(!qoi.is_valid()) {
    return make_result_error(env, "qoi_codec_not_available");
  }

  BLResult wr = canvas->img.write_to_data(qoi_data, qoi);
  if(wr != BL_SUCCESS) {
    return make_result_error(env, "qoi_encode_failed");
  }

  ERL_NIF_TERM bin;
  unsigned char* buf = enif_make_new_binary(env, qoi_data.size(), &bin);
  if(qoi_data.size() > 0) {
    std::memcpy(buf, qoi_data.data(), qoi_data.size());
  }

  return make_result_ok(env, bin);
}
