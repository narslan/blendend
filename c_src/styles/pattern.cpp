#include "../geometries/matrix2d.h"
#include "../images/image.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"
#include "styles.h"

// pattern_from_image(ImageRes)
ERL_NIF_TERM pattern_create(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto img = NifResource<Image>::get(env, argv[0]);
  if(img == nullptr) {
    return make_result_error(env, "invalid_pattern_component");
  }

  auto pattern = NifResource<Pattern>::alloc();

  BLResult r = pattern->value.create(img->value);
  if(r != BL_SUCCESS) {
    pattern->destroy();
    return make_result_error(env, "pattern_create_failed");
  }

  return make_result_ok(env, NifResource<Pattern>::make(env, pattern));
}

ERL_NIF_TERM pattern_set_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto pattern = NifResource<Pattern>::get(env, argv[0]);
  auto matrix = NifResource<Matrix2D>::get(env, argv[1]);
  if(pattern == nullptr || matrix == nullptr) {
    return make_result_error(env, "invalid_pattern_set_transform_resource");
  }

  BLResult r = pattern->value.set_transform(matrix->value);
  if(r != BL_SUCCESS)
    return make_result_error(env, "pattern_set_transform_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM pattern_reset_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto pattern = NifResource<Pattern>::get(env, argv[0]);
  if(pattern == nullptr) {
    return make_result_error(env, "invalid_pattern_reset_transform_resource");
  }

  BLResult r = pattern->value.reset_transform();
  if(r != BL_SUCCESS)
    return make_result_error(env, "pattern_reset_transform_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM pattern_set_extend(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto pattern = NifResource<Pattern>::get(env, argv[0]);
  if(pattern == nullptr) {
    return make_result_error(env, "invalid_pattern_set_extend_resource");
  }

  char atom[32];
  if(!enif_get_atom(env, argv[1], atom, sizeof(atom), ERL_NIF_UTF8)) {
    return make_result_error(env, "invalid_pattern_extend_atom");
  }

  BLExtendMode mode;

  if(!strcmp(atom, "pad")) {
    mode = BL_EXTEND_MODE_PAD;
  }
  else if(!strcmp(atom, "repeat")) {
    mode = BL_EXTEND_MODE_REPEAT;
  }
  else if(!strcmp(atom, "reflect")) {
    mode = BL_EXTEND_MODE_REFLECT;
  }
  else if(!strcmp(atom, "pad_x_repeat_y")) {
    mode = BL_EXTEND_MODE_PAD_X_REPEAT_Y;
  }
  else if(!strcmp(atom, "pad_x_reflect_y")) {
    mode = BL_EXTEND_MODE_PAD_X_REFLECT_Y;
  }
  else if(!strcmp(atom, "repeat_x_pad_y")) {
    mode = BL_EXTEND_MODE_REPEAT_X_PAD_Y;
  }
  else if(!strcmp(atom, "repeat_x_reflect_y")) {
    mode = BL_EXTEND_MODE_REPEAT_X_REFLECT_Y;
  }
  else if(!strcmp(atom, "reflect_x_pad_y")) {
    mode = BL_EXTEND_MODE_REFLECT_X_PAD_Y;
  }
  else if(!strcmp(atom, "reflect_x_repeat_y")) {
    mode = BL_EXTEND_MODE_REFLECT_X_REPEAT_Y;
  }
  else {
    return make_result_error(env, "invalid_pattern_extend_mode");
  }

  BLResult r = pattern->value.set_extend_mode(mode);
  if(r != BL_SUCCESS)
    return make_result_error(env, "pattern_set_extend_failed");

  return enif_make_atom(env, "ok");
}
