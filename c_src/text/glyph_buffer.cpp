#include "glyph_buffer.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"

#include "erl_nif.h"
#include <blend2d/core/glyphrun.h>

ERL_NIF_TERM glyph_buffer_new(ErlNifEnv* env,
                              [[maybe_unused]] int argc,
                              [[maybe_unused]] const ERL_NIF_TERM argv[])
{
  auto res = NifResource<GlyphBuffer>::alloc();
  return make_result_ok(env, NifResource<GlyphBuffer>::make(env, res));
}

ERL_NIF_TERM glyph_buffer_set_utf8_text(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto gb = NifResource<GlyphBuffer>::get(env, argv[0]);
  if(gb == nullptr) {
    return enif_make_badarg(env);
  }

  ErlNifBinary bin;
  if(!enif_inspect_binary(env, argv[1], &bin)) {
    return enif_make_badarg(env);
  }

  const char* text = reinterpret_cast<const char*>(bin.data);
  gb->value.set_utf8_text(text, bin.size);
  return enif_make_atom(env, "ok");
}

ERL_NIF_TERM glyph_buffer_glyph_run(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto gb = NifResource<GlyphBuffer>::get(env, argv[0]);
  if(gb == nullptr) {
    return enif_make_badarg(env);
  }

  const BLGlyphRun& run = gb->value.glyph_run();

  // Wenn run.size == 0 -> leeres Ergebnis
  if(run.size == 0) {
    ERL_NIF_TERM empty_map = enif_make_new_map(env);
    enif_make_map_put(
        env, empty_map, make_binary_from_str(env, "glyphs"), enif_make_list(env, 0), &empty_map);
    enif_make_map_put(
        env, empty_map, make_binary_from_str(env, "positions"), enif_make_list(env, 0), &empty_map);
    enif_make_map_put(
        env, empty_map, make_binary_from_str(env, "size"), enif_make_uint(env, 0), &empty_map);
    return make_result_ok(env, empty_map);
  }

  std::vector<ERL_NIF_TERM> glyph_terms;
  std::vector<ERL_NIF_TERM> position_terms;
  glyph_terms.reserve(run.size);
  position_terms.reserve(run.size);

  BLGlyphRunIterator it(run);
  while(!it.at_end()) {
    BLGlyphId gid = it.glyph_id(); // uint32_t
    BLPoint placement = it.placement<BLPoint>();

    ERL_NIF_TERM gid_term = enif_make_uint(env, (unsigned)gid);
    ERL_NIF_TERM pos_term = enif_make_tuple2(
        env, enif_make_double(env, placement.x), enif_make_double(env, placement.y));

    glyph_terms.push_back(gid_term);
    position_terms.push_back(pos_term);

    it.advance();
  }

  ERL_NIF_TERM glyphs_list =
      enif_make_list_from_array(env, glyph_terms.data(), (unsigned)glyph_terms.size());
  ERL_NIF_TERM positions_list =
      enif_make_list_from_array(env, position_terms.data(), (unsigned)position_terms.size());

  // Compose map { glyphs: [...], positions: [...], size: N }
  ERL_NIF_TERM map = enif_make_new_map(env);
  enif_make_map_put(env, map, make_binary_from_str(env, "glyphs"), glyphs_list, &map);
  enif_make_map_put(env, map, make_binary_from_str(env, "positions"), positions_list, &map);
  enif_make_map_put(
      env, map, make_binary_from_str(env, "size"), enif_make_uint(env, (unsigned)run.size), &map);

  return make_result_ok(env, map);
}
