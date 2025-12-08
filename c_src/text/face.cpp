#include "font.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"

ERL_NIF_TERM face_load(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  ErlNifBinary bin;
  if(!enif_inspect_binary(env, argv[0], &bin)) {
    return make_result_error(env, "font_face_load_invalid_data");
  }

  auto res = NifResource<FontFace>::alloc();

  // Keep a private copy of the binary term to extend its lifetime without duplicating data.
  res->bin_env = enif_alloc_env();
  if(!res->bin_env) {
    res->destroy();
    return make_result_error(env, "font_data_alloc_env_failed");
  }

  res->bin_term = enif_make_copy(res->bin_env, argv[0]);

  ErlNifBinary persisted_bin;
  if(!enif_inspect_binary(res->bin_env, res->bin_term, &persisted_bin)) {
    if(res->bin_env) {
      enif_free_env(res->bin_env);
      res->bin_env = nullptr;
    }
    res->destroy();
    return make_result_error(env, "font_face_load_invalid_data");
  }

  // Create BLFontData pointing at the binary owned by bin_env (no copy).
  BLResult r = res->data.create_from_data(
      persisted_bin.data,
      persisted_bin.size,
      nullptr,
      nullptr);

  if(r != BL_SUCCESS) {
    if(res->bin_env) {
      enif_free_env(res->bin_env);
      res->bin_env = nullptr;
    }
    res->destroy();
    return make_result_error(env, "font_data_create_failed");
  }

  r = res->value.create_from_data(res->data, /*faceIndex=*/0);
  if(r != BL_SUCCESS) {
    res->destroy();
    return make_result_error(env, "font_face_load_failed");
  }

  return make_result_ok(env, NifResource<FontFace>::make(env, res));
}




ERL_NIF_TERM face_design_metrics(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto face = NifResource<FontFace>::get(env, argv[0]);
  if(face == nullptr)
    return make_result_error(env, "face_design_metrics_invalid_face");

  BLFontDesignMetrics dm = face->value.design_metrics();

  ERL_NIF_TERM map = enif_make_new_map(env);
  PUT_NUM(env, map, "units_per_em", dm.units_per_em);
  PUT_NUM(env, map, "ascent", dm.ascent);
  PUT_NUM(env, map, "v_ascent", dm.ascent);
  PUT_NUM(env, map, "descent", dm.descent);
  PUT_NUM(env, map, "v_descent", dm.descent);
  PUT_NUM(env, map, "line_gap", dm.line_gap);
  PUT_NUM(env, map, "x_height", dm.x_height);
  PUT_NUM(env, map, "cap_height", dm.cap_height);
  PUT_NUM(env, map, "h_min_tsb", dm.h_min_tsb);
  PUT_NUM(env, map, "h_min_lsb", dm.h_min_lsb);
  return make_result_ok(env, map);
}

static ERL_NIF_TERM bltag_to_bin(ErlNifEnv* env, uint32_t tag)
{
  // tag is big-endian 4 chars
  unsigned char buf[4];
  buf[0] = (tag >> 24) & 0xFF;
  buf[1] = (tag >> 16) & 0xFF;
  buf[2] = (tag >> 8) & 0xFF;
  buf[3] = (tag >> 0) & 0xFF;

  ErlNifBinary bin;
  enif_alloc_binary(4, &bin);
  memcpy(bin.data, buf, 4);

  return enif_make_binary(env, &bin);
}


ERL_NIF_TERM face_get_feature_tags(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1)
    return enif_make_badarg(env);

  auto face = NifResource<FontFace>::get(env, argv[0]);
  if(face == nullptr)
    return make_result_error(env, "invalid_face_get_feature_tags_resource");

  BLArray<BLTag> tags;
  BLResult r = face->value.get_feature_tags(&tags);
  if(r != BL_SUCCESS)
    return make_result_error(env, "face_get_feature_tags_failed");

  ERL_NIF_TERM list = enif_make_list(env, 0);

  const BLTag* data = tags.data();
  const size_t count = tags.size();

  for(size_t i = 0; i < count; ++i) {
    uint32_t tag = data[i];
    ERL_NIF_TERM bin = bltag_to_bin(env, tag);

    list = enif_make_list_cell(env, bin, list);
  }

  return make_result_ok(env, list);
}
