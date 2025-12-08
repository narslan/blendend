#include "../geometries/matrix2d.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"
#include "styles.h"

ERL_NIF_TERM gradient_linear(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  double x0, y0, x1, y1;

  if(argc != 4) {
    return enif_make_badarg(env);
  }

  if(!enif_get_double(env, argv[0], &x0) || !enif_get_double(env, argv[1], &y0) ||
     !enif_get_double(env, argv[2], &x1) || !enif_get_double(env, argv[3], &y1)) {
    return make_result_error(env, "invalid_linear_gradient_component");
  }

  Gradient* res = NifResource<Gradient>::alloc();
  res->value = BLGradient(BLLinearGradientValues(x0, y0, x1, y1));

  return make_result_ok(env, NifResource<Gradient>::make(env, res));
}

ERL_NIF_TERM gradient_radial(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  // Arguments match BLRadialGradientValues: x0, y0, x1, y1, r0, r1
  double x0, y0, x1, y1, r0, r1;

  if(argc != 6) {
    return enif_make_badarg(env);
  }

  if(!enif_get_double(env, argv[0], &x0) || !enif_get_double(env, argv[1], &y0) ||
     !enif_get_double(env, argv[2], &x1) || !enif_get_double(env, argv[3], &y1) ||
     !enif_get_double(env, argv[4], &r0) || !enif_get_double(env, argv[5], &r1)) {
    return make_result_error(env, "invalid_radial_gradient_component");
  }

  Gradient* res = NifResource<Gradient>::alloc();
  res->value = BLGradient(BLRadialGradientValues(x0, y0, x1, y1, r0, r1));

  return make_result_ok(env, NifResource<Gradient>::make(env, res));
}

ERL_NIF_TERM gradient_conic(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  double x0, y0, angle;

  if(argc != 3) {
    return enif_make_badarg(env);
  }

  if(!enif_get_double(env, argv[0], &x0) || !enif_get_double(env, argv[1], &y0) ||
     !enif_get_double(env, argv[2], &angle)) {
    return make_result_error(env, "invalid_conic_gradient_component");
  }

  Gradient* res = NifResource<Gradient>::alloc();
  res->value = BLGradient(BLConicGradientValues(x0, y0, angle));

  return make_result_ok(env, NifResource<Gradient>::make(env, res));
}

// Add color stop
ERL_NIF_TERM gradient_add_stop(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3) {
    return enif_make_badarg(env);
  }

  double offset;
  auto grad = NifResource<Gradient>::get(env, argv[0]);
  auto color = NifResource<Color>::get(env, argv[2]);

  if(grad == nullptr || color == nullptr || !enif_get_double(env, argv[1], &offset)) {
    return make_result_error(env, "invalid_add_stop");
  }

  BLResult r = grad->value.add_stop(offset, color->value);
  if(r != BL_SUCCESS)
    return make_result_error(env, "gradient_add_stop_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM gradient_set_extend(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto grad = NifResource<Gradient>::get(env, argv[0]);
  if(grad == nullptr) {
    return make_result_error(env, "invalid_gradient_resource");
  }

  char atom[32];
  if(!enif_get_atom(env, argv[1], atom, sizeof(atom), ERL_NIF_UTF8)) {
    return make_result_error(env, "invalid_gradient_extend_atom");
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
  else {
    // unknown mode
    return make_result_error(env, "invalid_gradient_extend_mode");
  }

  BLResult r = grad->value.set_extend_mode(mode);
  if(r != BL_SUCCESS)
    return make_result_error(env, "failed_gradient_set_extend");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM gradient_set_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto grad = NifResource<Gradient>::get(env, argv[0]);
  auto matrix = NifResource<Matrix2D>::get(env, argv[1]);

  if(grad == nullptr || matrix == nullptr) {
    return make_result_error(env, "invalid_set_transform_resource");
  }

  BLResult r = grad->value.set_transform(matrix->value);
  if(r != BL_SUCCESS)
    return make_result_error(env, "gradient_set_transform_failed");

  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM gradient_reset_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto grad = NifResource<Gradient>::get(env, argv[0]);
  if(grad == nullptr) {
    return make_result_error(env, "invalid_gradient_reset_transform_resource");
  }

  BLResult r = grad->value.reset_transform();
  if(r != BL_SUCCESS)
    return make_result_error(env, "gradient_reset_transform_failed");

  return enif_make_atom(env, "ok");
}
