#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"
#include "styles.h"
#include <algorithm>
#include <blend2d/blend2d.h>

ERL_NIF_TERM color(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  int r, g, b, a;

  if(argc != 4) {
    return enif_make_badarg(env);
  }

  if(!enif_get_int(env, argv[0], &r) || !enif_get_int(env, argv[1], &g) ||
     !enif_get_int(env, argv[2], &b) || !enif_get_int(env, argv[3], &a)) {
    return make_result_error(env, "invalid_color_component");
  }

  r = std::clamp(r, 0, 255);
  g = std::clamp(g, 0, 255);
  b = std::clamp(b, 0, 255);
  a = std::clamp(a, 0, 255);

  auto color = NifResource<Color>::alloc();
  color->value = BLRgba32(r, g, b, a);

  return make_result_ok(env, NifResource<Color>::make(env, color));
}

ERL_NIF_TERM color_components(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto color = NifResource<Color>::get(env, argv[0]);
  if(color == nullptr) {
    return make_result_error(env, "invalid_color_resource");
  }

  BLRgba32 c = color->value;
  ERL_NIF_TERM tuple =
      enif_make_tuple4(env,
                       enif_make_int(env, c.r()),
                       enif_make_int(env, c.g()),
                       enif_make_int(env, c.b()),
                       enif_make_int(env, c.a()));

  return make_result_ok(env, tuple);
}
