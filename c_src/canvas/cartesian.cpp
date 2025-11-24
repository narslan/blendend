#include "cartesian.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"

template <>
const char* NifResource<Cartesian>::resource_name = "CartesianRes";

// Cartesian.new(x_min, x_max, y_min, y_max, width, height)
ERL_NIF_TERM cartesian(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 6)
    return enif_make_badarg(env);
  double x_min, x_max, y_min, y_max;
  unsigned int width, height;

  if(!enif_get_double(env, argv[0], &x_min) || !enif_get_double(env, argv[1], &x_max) ||
     !enif_get_double(env, argv[2], &y_min) || !enif_get_double(env, argv[3], &y_max) ||
     !enif_get_uint(env, argv[4], &width) || !enif_get_uint(env, argv[5], &height)) {
    return make_result_error(env, "cartesian_new_invalid_resource");
  }

  Cartesian* cartesian = NifResource<Cartesian>::alloc();
  *cartesian = Cartesian(x_min, x_max, y_min, y_max, width, height, true);

  return make_result_ok(env, NifResource<Cartesian>::make(env, cartesian));
}

// Cartesian.to_canvas(cartesian, x, y)
ERL_NIF_TERM cartesian_to_canvas(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  Cartesian* cartesian;
  double x, y;

  if(!(cartesian = NifResource<Cartesian>::get(env, argv[0])) ||
     !enif_get_double(env, argv[1], &x) || !enif_get_double(env, argv[2], &y)) {
    return make_result_error(env, "cartesian_to_canvas_invalid_resource");
  }

  BLPoint p = cartesian->to_canvas(x, y);
  ERL_NIF_TERM tuple =
      enif_make_tuple2(env, enif_make_double(env, p.x), enif_make_double(env, p.y));
  return make_result_ok(env, tuple);
}

// Cartesian.to_math(cartesian, px, py)
ERL_NIF_TERM cartesian_to_math(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{

  if(argc != 3)
    return enif_make_badarg(env);

  Cartesian* cartesian;
  double px, py;

  if(!(cartesian = NifResource<Cartesian>::get(env, argv[0])) ||
     !enif_get_double(env, argv[1], &px) || !enif_get_double(env, argv[2], &py)) {
    return make_result_error(env, "cartesian_to_math_invalid_resource");
  }

  BLPoint p = cartesian->to_math(px, py);
  ERL_NIF_TERM tuple =
      enif_make_tuple2(env, enif_make_double(env, p.x), enif_make_double(env, p.y));
  return make_result_ok(env, tuple);
}
