#include "matrix2d.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"

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

// matrix2d_post_scale(matrix, sx, sy) :: matrix
ERL_NIF_TERM matrix2d_post_scale(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  if(!src)
    return make_result_error(env, "matrix_post_scale_invalid_matrix");

  double sx = 0.0, sy = 0.0;
  if(!enif_get_double(env, argv[1], &sx) || !enif_get_double(env, argv[2], &sy)) {
    return make_result_error(env, "matrix_post_scale_invalid_values");
  }

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.post_scale(sx, sy) != BL_SUCCESS) {
    enif_release_resource(dst);
    return make_result_error(env, "failed_matrix_post_scale");
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

// matrix2d_rotate_at(matrix, angle, cx, cy) :: matrix
ERL_NIF_TERM matrix2d_rotate_at(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 4)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  if(!src)
    return make_result_error(env, "matrix_rotate_at_invalid_matrix");

  double angle = 0.0, cx = 0.0, cy = 0.0;
  if(!enif_get_double(env, argv[1], &angle) || !enif_get_double(env, argv[2], &cx) ||
     !enif_get_double(env, argv[3], &cy)) {
    return make_result_error(env, "matrix_rotate_at_invalid_values");
  }

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.rotate(angle, cx, cy) != BL_SUCCESS) {
    enif_release_resource(dst);
    return make_result_error(env, "failed_matrix_rotate_at");
  }

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}

// matrix2d_post_rotate(matrix, angle, cx, cy) :: matrix
ERL_NIF_TERM matrix2d_post_rotate(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 4)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  if(!src)
    return make_result_error(env, "matrix_post_rotate_invalid_matrix");

  double angle = 0.0, cx = 0.0, cy = 0.0;
  if(!enif_get_double(env, argv[1], &angle) || !enif_get_double(env, argv[2], &cx) ||
     !enif_get_double(env, argv[3], &cy)) {
    return make_result_error(env, "matrix_post_rotate_invalid_values");
  }

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.post_rotate(angle, cx, cy) != BL_SUCCESS) {
    enif_release_resource(dst);
    return make_result_error(env, "failed_matrix_post_rotate");
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

// matrix2d_post_skew(matrix, kx, ky) :: matrix
ERL_NIF_TERM matrix2d_post_skew(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  if(!src)
    return make_result_error(env, "matrix_post_skew_invalid_matrix");

  double kx = 0.0;
  double ky = 0.0;

  if(!enif_get_double(env, argv[1], &kx) || !enif_get_double(env, argv[2], &ky)) {
    return make_result_error(env, "matrix_post_skew_invalid_values");
  }

  Matrix2D* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.post_skew(kx, ky) != BL_SUCCESS) {
    enif_release_resource(dst);
    return make_result_error(env, "failed_matrix_post_skew");
  }

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}

// matrix2d_transform(matrix, other) :: matrix (pre-multiply by other)
ERL_NIF_TERM matrix2d_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  Matrix2D* other = NifResource<Matrix2D>::get(env, argv[1]);
  if(!src || !other)
    return make_result_error(env, "matrix_transform_invalid_matrix");

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.transform(other->value) != BL_SUCCESS) {
    enif_release_resource(dst);
    return make_result_error(env, "failed_matrix_transform");
  }

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}

// matrix2d_post_transform(matrix, other) :: matrix (post-multiply by other)
ERL_NIF_TERM matrix2d_post_transform(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  Matrix2D* other = NifResource<Matrix2D>::get(env, argv[1]);
  if(!src || !other)
    return make_result_error(env, "matrix_post_transform_invalid_matrix");

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.post_transform(other->value) != BL_SUCCESS) {
    enif_release_resource(dst);
    return make_result_error(env, "failed_matrix_post_transform");
  }

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}

// matrix2d_invert(matrix) :: matrix
ERL_NIF_TERM matrix2d_invert(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  Matrix2D* src = NifResource<Matrix2D>::get(env, argv[0]);
  if(!src)
    return make_result_error(env, "matrix_invert_invalid_matrix");

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = src->value;

  if(dst->value.invert() != BL_SUCCESS) {
    enif_release_resource(dst);
    return make_result_error(env, "matrix_invert_failed");
  }

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}

// matrix2d_map_point(matrix, x, y) :: {ok, {x, y}}
ERL_NIF_TERM matrix2d_map_point(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  Matrix2D* m = NifResource<Matrix2D>::get(env, argv[0]);
  if(!m)
    return make_result_error(env, "matrix_map_point_invalid_matrix");

  double x = 0.0, y = 0.0;
  if(!enif_get_double(env, argv[1], &x) || !enif_get_double(env, argv[2], &y)) {
    return make_result_error(env, "matrix_map_point_invalid_values");
  }

  BLPoint p = m->value.map_point(x, y);
  ERL_NIF_TERM tup = enif_make_tuple2(env, enif_make_double(env, p.x), enif_make_double(env, p.y));
  return make_result_ok(env, tup);
}

// matrix2d_map_vector(matrix, x, y) :: {ok, {x, y}}
ERL_NIF_TERM matrix2d_map_vector(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  Matrix2D* m = NifResource<Matrix2D>::get(env, argv[0]);
  if(!m)
    return make_result_error(env, "matrix_map_vector_invalid_matrix");

  double x = 0.0, y = 0.0;
  if(!enif_get_double(env, argv[1], &x) || !enif_get_double(env, argv[2], &y)) {
    return make_result_error(env, "matrix_map_vector_invalid_values");
  }

  BLPoint p = m->value.map_vector(x, y);
  ERL_NIF_TERM tup = enif_make_tuple2(env, enif_make_double(env, p.x), enif_make_double(env, p.y));
  return make_result_ok(env, tup);
}

// matrix2d_make_sin_cos(sin, cos, tx, ty) :: matrix
ERL_NIF_TERM matrix2d_make_sin_cos(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 4)
    return enif_make_badarg(env);

  double s = 0.0, c = 0.0, tx = 0.0, ty = 0.0;
  if(!enif_get_double(env, argv[0], &s) || !enif_get_double(env, argv[1], &c) ||
     !enif_get_double(env, argv[2], &tx) || !enif_get_double(env, argv[3], &ty)) {
    return make_result_error(env, "matrix_make_sin_cos_invalid_values");
  }

  auto* dst = NifResource<Matrix2D>::alloc();
  dst->value = BLMatrix2D::make_sin_cos(s, c, tx, ty);

  return make_result_ok(env, NifResource<Matrix2D>::make(env, dst));
}
