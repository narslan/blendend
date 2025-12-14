#include "canvas.h"
#include "../geometries/matrix2d.h"
#include "../images/image.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"
#include "../styles/styles.h"

#include <blend2d/blend2d.h>

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
