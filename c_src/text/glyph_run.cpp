#include "glyph_run.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"
#include "../text/glyph_buffer.h"
#include "erl_nif.h"

ERL_NIF_TERM glyph_run_new(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  auto gb = NifResource<GlyphBuffer>::get(env, argv[0]);
  if(gb == nullptr)
    return make_result_error(env, "glyph_run_new_invalid_glyph_buffer");

  auto* gr = NifResource<GlyphRun>::alloc();
  gr->run = gb->value.glyph_run();
  gr->owner = gb;
  enif_keep_resource(gb);

  return make_result_ok(env, NifResource<GlyphRun>::make(env, gr));
}

ERL_NIF_TERM glyph_run_info(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto gr = NifResource<GlyphRun>::get(env, argv[0]);
  if(gr == nullptr) {
    return make_result_error(env, "glyph_run_info_invalid_glyph_run");
  }

  const BLGlyphRun& run = gr->run;

  ERL_NIF_TERM map = enif_make_new_map(env);

  auto put = [&](const char* key, ERL_NIF_TERM value) {
    enif_make_map_put(env, map, enif_make_atom(env, key), value, &map);
  };

  put("size", enif_make_ulong(env, (unsigned long)run.size));
  put("placement_type", enif_make_uint(env, run.placement_type));
  put("glyph_advance", enif_make_int(env, run.glyph_advance));
  put("placement_advance", enif_make_int(env, run.placement_advance));
  put("flags", enif_make_uint(env, run.flags));

  return make_result_ok(env, map);
}

static ERL_NIF_TERM placement_type_atom(ErlNifEnv* env, uint8_t t)
{
  switch(t) {
  case BL_GLYPH_PLACEMENT_TYPE_NONE:
    return enif_make_atom(env, "none");
  case BL_GLYPH_PLACEMENT_TYPE_ADVANCE_OFFSET:
    return enif_make_atom(env, "advance_offset");
  case BL_GLYPH_PLACEMENT_TYPE_DESIGN_UNITS:
    return enif_make_atom(env, "design_units");
  case BL_GLYPH_PLACEMENT_TYPE_USER_UNITS:
    return enif_make_atom(env, "user_units");
  case BL_GLYPH_PLACEMENT_TYPE_ABSOLUTE_UNITS:
    return enif_make_atom(env, "absolute_units");
  default:
    return enif_make_atom(env, "unknown");
  }
}

static ERL_NIF_TERM make_point(ErlNifEnv* env, double x, double y)
{
  return enif_make_tuple2(env, enif_make_double(env, x), enif_make_double(env, y));
}

ERL_NIF_TERM glyph_run_inspect(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto gr = NifResource<GlyphRun>::get(env, argv[0]);
  if(gr == nullptr) {
    return make_result_error(env, "glyph_run_inspect_invalid_glyph_run");
  }

  const BLGlyphRun& run = gr->run;
  BLGlyphRunIterator it(run);

  ERL_NIF_TERM list = enif_make_list(env, 0);

  while(!it.at_end()) {
    uint32_t glyph_id = it.glyph_id();
    ERL_NIF_TERM placement_term;

    if(it.has_placement()) {
      uint8_t pt = run.placement_type;
      ERL_NIF_TERM pt_atom = placement_type_atom(env, pt);

      if(pt == BL_GLYPH_PLACEMENT_TYPE_ADVANCE_OFFSET) {
        const BLGlyphPlacement& pl = it.placement<BLGlyphPlacement>();

        ERL_NIF_TERM adv = make_point(env, double(pl.advance.x), double(pl.advance.y));
        ERL_NIF_TERM off = make_point(env, double(pl.placement.x), double(pl.placement.y));

        placement_term = enif_make_tuple3(env, pt_atom, adv, off);
      }
      else {
        const BLPoint& pos = it.placement<BLPoint>();

        placement_term = enif_make_tuple3(
            env, pt_atom, enif_make_double(env, pos.x), enif_make_double(env, pos.y));
      }
    }
    else {
      placement_term = enif_make_atom(env, "none");
    }

    ERL_NIF_TERM glyph_term = enif_make_tuple3(
        env, enif_make_atom(env, "glyph"), enif_make_uint(env, glyph_id), placement_term);

    list = enif_make_list_cell(env, glyph_term, list);
    it.advance();
  }

  ERL_NIF_TERM out = enif_make_list(env, 0);
  ERL_NIF_TERM head, tail;
  while(enif_get_list_cell(env, list, &head, &tail)) {
    out = enif_make_list_cell(env, head, out);
    list = tail;
  }

  return make_result_ok(env, out);
}

ERL_NIF_TERM glyph_run_slice(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3)
    return enif_make_badarg(env);

  unsigned start = 0;
  unsigned count = 0;

  auto src = NifResource<GlyphRun>::get(env, argv[0]);
  if(src == nullptr || !enif_get_uint(env, argv[1], &start) ||
     !enif_get_uint(env, argv[2], &count)) {
    return make_result_error(env, "glyph_run_slice_invalid_args");
  }

  if(start > src->run.size || count > src->run.size - start)
    return make_result_error(env, "glyph_run_slice_out_of_range");

  GlyphRun* dst = NifResource<GlyphRun>::alloc();
  if(!dst)
    return make_result_error(env, "glyph_run_alloc_failed");

  dst->run = src->run;

  dst->owner = src->owner;
  if(dst->owner)
    enif_keep_resource(dst->owner);

  const uint8_t glyph_adv = src->run.glyph_advance;
  const uint8_t placement_adv = src->run.placement_advance;

  dst->run.glyph_data =
      static_cast<void*>(static_cast<uint8_t*>(src->run.glyph_data) + start * glyph_adv);

  dst->run.placement_data =
      static_cast<void*>(static_cast<uint8_t*>(src->run.placement_data) + start * placement_adv);

  dst->run.size = count;

  return make_result_ok(env, NifResource<GlyphRun>::make(env, dst));
}
