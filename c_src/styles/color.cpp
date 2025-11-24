#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"
#include "styles.h"
#include <algorithm>
#include <blend2d/blend2d.h>

template <>
const char* NifResource<Color>::resource_name = "ColorRes";

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
