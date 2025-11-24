#include "matrix2d.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"

template <>
const char* NifResource<Matrix2D>::resource_name = "Matrix2D";

// matrix2d_identity() -> {ok, Matrix2DRes}
// Returns an identity matrix (1,0,0,1,0,0).
ERL_NIF_TERM matrix2d_identity(ErlNifEnv* env, int, const ERL_NIF_TERM[])
{
  auto* res = NifResource<Matrix2D>::alloc();
  res->value.reset();
  return make_result_ok(env, NifResource<Matrix2D>::make(env, res));
}

// matrix2d_new([m00, m01, m10, m11, tx, ty]) -> {ok, Matrix2DRes}
//
// We accept a *list* to keep it Elixir-ish.
ERL_NIF_TERM matrix2d_new(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 1) {
    return enif_make_badarg(env);
  }

  if(!enif_is_list(env, argv[0]))
    return make_result_error(env, "matrix_new_invalid_list");

  // Blend2D uses this layout:
  // [ m00, m01, m10, m11, m20, m21]
  // which maps to:
  // [ m00, m01, m10, m11,  tx,  ty]
  double m[6];
  unsigned len;

  if(!enif_get_list_length(env, argv[0], &len) || len != 6)
    return make_result_error(env, "matrix_new_invalid_list");

  ERL_NIF_TERM head, tail = argv[0];
  for(unsigned i = 0; i < 6; ++i) {
    if(!enif_get_list_cell(env, tail, &head, &tail) || !enif_get_double(env, head, &m[i]))
      return make_result_error(env, "matrix_new_invalid_list");
  }

  auto* res = NifResource<Matrix2D>::alloc();
  res->value = BLMatrix2D(m[0], m[1], m[2], m[3], m[4], m[5]);
  return make_result_ok(env, NifResource<Matrix2D>::make(env, res));
}

// @spec matrix2d_to_list(matrix) :: [float()]
ERL_NIF_TERM matrix2d_to_list(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  Matrix2D* mat = NifResource<Matrix2D>::get(env, argv[0]);
  if(!mat)
    return make_result_error(env, "matrix_to_list_invalid_matrix");

  const auto& m = mat->value;

  ERL_NIF_TERM elems[6] = {
      enif_make_double(env, m.m00),
      enif_make_double(env, m.m01),
      enif_make_double(env, m.m10),
      enif_make_double(env, m.m11),
      enif_make_double(env, m.m20),
      enif_make_double(env, m.m21),
  };

  return make_result_ok(env, enif_make_list_from_array(env, elems, 6));
}

// -----------------------------------------------------------------------------
// matrix2d_translate/3
// -----------------------------------------------------------------------------

// @spec matrix2d_translate(matrix, float(), float()) :: matrix
ERL_NIF_TERM matrix2d_translate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  if(!src)
    return make_result_error(env, "matrix_translate_invalid_matrix");

  double tx = 0.0, ty = 0.0;
  if(!enif_get_double(env, argv[1], &tx) || !enif_get_double(env, argv[2], &ty)) {
    return make_result_error(env, "matrix_translate_invalid_values");
  }

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.translate(tx, ty) != BL_SUCCESS) {
    enif_release_resource(dst);
    return enif_make_badarg(env);
  }

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}

// matrix2d_post_translate/3 (post-multiply by translation)
ERL_NIF_TERM matrix2d_post_translate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  if(!src)
    return make_result_error(env, "matrix_post_translate_invalid_matrix");

  double tx = 0.0, ty = 0.0;
  if(!enif_get_double(env, argv[1], &tx) || !enif_get_double(env, argv[2], &ty)) {
    return make_result_error(env, "matrix_post_translate_invalid_values");
  }

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.post_translate(tx, ty) != BL_SUCCESS) {
    enif_release_resource(dst);
    return enif_make_badarg(env);
  }

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}

// -----------------------------------------------------------------------------
// matrix2d_scale/3
// -----------------------------------------------------------------------------

// @spec matrix2d_scale(matrix, float(), float()) :: matrix
ERL_NIF_TERM matrix2d_scale(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  if(!src)
    return make_result_error(env, "matrix_scale_invalid_matrix");

  double sx = 0.0, sy = 0.0;
  if(!enif_get_double(env, argv[1], &sx) || !enif_get_double(env, argv[2], &sy)) {
    return make_result_error(env, "matrix_scale_invalid_values");
  }

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.scale(sx, sy) != BL_SUCCESS) {
    enif_release_resource(dst);
    return make_result_error(env, "failed_matrix_scale");
  }

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}

// -----------------------------------------------------------------------------
// matrix2d_rotate/2
// -----------------------------------------------------------------------------

// @spec matrix2d_rotate(matrix, float()) :: matrix
// angle in radians, counter-clockwise
ERL_NIF_TERM matrix2d_rotate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  if(!src)
    return make_result_error(env, "matrix_rotate_invalid_matrix");

  double angle = 0.0;
  if(!enif_get_double(env, argv[1], &angle)) {
    return make_result_error(env, "matrix_rotate_invalid_value");
  }

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.rotate(angle) != BL_SUCCESS) {
    enif_release_resource(dst);
    return make_result_error(env, "failed_matrix_rotate");
  }

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}

// matrix2d_skew(matrix, kx, ky) :: matrix
// kx, ky are skew angles in radians along X and Y axes.
ERL_NIF_TERM matrix2d_skew(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  if(!src)
    return make_result_error(env, "matrix_skew_invalid_matrix");

  double kx = 0.0;
  double ky = 0.0;

  if(!enif_get_double(env, argv[1], &kx) || !enif_get_double(env, argv[2], &ky)) {
    return make_result_error(env, "matrix_skew_invalid_values");
  }

  // functional: copy source and skew the copy
  Matrix2D* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.skew(kx, ky) != BL_SUCCESS) {
    enif_release_resource(dst);
    return make_result_error(env, "failed_matrix_scale");
  }

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}

// matrix_compose(matrix_a, matrix_b) :: Matrix2D
// Returns a new matrix c such that: c = b * a
// (i.e. `b` is pre-composed with `a`).
// matrix_compose(a, b) :: Matrix2D

ERL_NIF_TERM matrix2d_compose(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  Matrix2D* a = NifResource<Matrix2D>::get(env, argv[0]);
  Matrix2D* b = NifResource<Matrix2D>::get(env, argv[1]);
  if(!a || !b)
    return make_result_error(env, "matrix_compose_invalid_matrix");

  const BLMatrix2D& ma = a->value;
  const BLMatrix2D& mb = b->value;

  const double a00 = ma.m00;
  const double a01 = ma.m01;
  const double a10 = ma.m10;
  const double a11 = ma.m11;
  const double atx = ma.m20;
  const double aty = ma.m21;

  const double b00 = mb.m00;
  const double b01 = mb.m01;
  const double b10 = mb.m10;
  const double b11 = mb.m11;
  const double btx = mb.m20;
  const double bty = mb.m21;

  const double c00 = a00 * b00 + a01 * b10;
  const double c01 = a00 * b01 + a01 * b11;
  const double c10 = a10 * b00 + a11 * b10;
  const double c11 = a10 * b01 + a11 * b11;
  const double ctx = a00 * btx + a01 * bty + atx;
  const double cty = a10 * btx + a11 * bty + aty;

  Matrix2D* dst = NifResource<Matrix2D>::alloc();
  dst->value.reset(c00, c01, c10, c11, ctx, cty);

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}
