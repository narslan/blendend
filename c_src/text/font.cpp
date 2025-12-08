#include "font.h"
#include "glyph_run.h"

#include "../geometries/matrix2d.h"
#include "../geometries/path.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"
#include "../text/glyph_buffer.h"

#include "erl_nif.h"
#include <cstring>

// font_create(FaceRes, double size)
ERL_NIF_TERM font_create(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto face = NifResource<FontFace>::get(env, argv[0]);
  if(face == nullptr) {
    return make_result_error(env, "font_create_invalid_resource");
  }

  double size;
  if(!enif_get_double(env, argv[1], &size)) {
    return make_result_error(env, "font_create_invalid_size");
  }

  auto res = NifResource<Font>::alloc();

  BLResult result = res->value.create_from_face(face->value, size);
  if(result != BL_SUCCESS) {
    res->destroy();
    return make_result_error(env, "font_create_failed");
  }

   // Keep the face resource alive for the lifetime of this font.
   res->owner = face;
   enif_keep_resource(face);

  return make_result_ok(env, NifResource<Font>::make(env, res));
}

// font_metrics(FontRes)
ERL_NIF_TERM font_metrics(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto font = NifResource<Font>::get(env, argv[0]);
  if(font == nullptr) {
    return make_result_error(env, "font_metrics_invalid_font");
  }

  BLFontMetrics metrics = font->value.metrics();
  ERL_NIF_TERM map = map_from_fields<BLFontMetrics>(
      env,
      metrics,
      {{"size", [](const BLFontMetrics& m) { return m.size; }},
       {"ascent", [](const BLFontMetrics& m) { return m.ascent; }},
       {"v_ascent", [](const BLFontMetrics& m) { return m.v_ascent; }},
       {"descent", [](const BLFontMetrics& m) { return m.descent; }},
       {"v_descent", [](const BLFontMetrics& m) { return m.v_descent; }},
       {"line_gap", [](const BLFontMetrics& m) { return m.line_gap; }},
       {"x_height", [](const BLFontMetrics& m) { return m.x_height; }},
       {"cap_height", [](const BLFontMetrics& m) { return m.cap_height; }},
       {"x_min", [](const BLFontMetrics& m) { return m.x_min; }},
       {"y_min", [](const BLFontMetrics& m) { return m.y_min; }},
       {"x_max", [](const BLFontMetrics& m) { return m.x_max; }},
       {"y_max", [](const BLFontMetrics& m) { return m.y_max; }},
       {"underline_position", [](const BLFontMetrics& m) { return m.underline_position; }},
       {"underline_thickness", [](const BLFontMetrics& m) { return m.underline_thickness; }},
       {"strikethrough_position", [](const BLFontMetrics& m) { return m.strikethrough_position; }},
       {"strikethrough_thickness",
        [](const BLFontMetrics& m) { return m.strikethrough_thickness; }}});

  return make_result_ok(env, map);
}

// shape(glyph_buffer, font)
// font_shape(FontRes, GlyphBufferRes)
ERL_NIF_TERM font_shape(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto font = NifResource<Font>::get(env, argv[0]);
  if(font == nullptr) {
    return make_result_error(env, "font_shape_invalid_font");
  }

  auto gb = NifResource<GlyphBuffer>::get(env, argv[1]);
  if(gb == nullptr) {
    return make_result_error(env, "font_shape_invalid_glyph_buffer");
  }

  BLResult result = font->value.shape(gb->value);
  if(result != BL_SUCCESS)
    return make_result_error(env, "font_shape_failed");

  return enif_make_atom(env, "ok");
}

// font_get_text_metrics(FontRes, GlyphBufferRes)
ERL_NIF_TERM font_get_text_metrics(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto font = NifResource<Font>::get(env, argv[0]);
  if(font == nullptr) {
    return make_result_error(env, "font_get_text_metrics_invalid_font");
  }

  auto gb = NifResource<GlyphBuffer>::get(env, argv[1]);
  if(gb == nullptr) {
    return make_result_error(env, "font_get_text_metrics_invalid_glyph_buffer");
  }

  BLTextMetrics metrics;
  BLResult result = font->value.get_text_metrics(gb->value, metrics);
  if(result != BL_SUCCESS)
    return make_result_error(env, "font_get_text_metrics_failed");

  ERL_NIF_TERM map = map_from_fields<BLTextMetrics>(
      env,
      metrics,
      {{"advance_x", [](const BLTextMetrics& m) { return m.advance.x; }},
       {"advance_y", [](const BLTextMetrics& m) { return m.advance.y; }},
       {"bbox_x0", [](const BLTextMetrics& m) { return m.bounding_box.x0; }},
       {"bbox_y0", [](const BLTextMetrics& m) { return m.bounding_box.y0; }},
       {"bbox_x1", [](const BLTextMetrics& m) { return m.bounding_box.x1; }},
       {"bbox_y1", [](const BLTextMetrics& m) { return m.bounding_box.y1; }}});

  return make_result_ok(env, map);
}
// font_get_glyph_run_outlines(FontRes, GlyphRunRes, Matrix2DRes, PathRes)
ERL_NIF_TERM font_get_glyph_run_outlines(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 4)
    return enif_make_badarg(env);

  auto font = NifResource<Font>::get(env, argv[0]);
  if(font == nullptr) {
    return make_result_error(env, "font_get_glyph_run_outlines_invalid_font");
  }

  auto gr = NifResource<GlyphRun>::get(env, argv[1]);
  if(gr == nullptr) {
    return make_result_error(env, "font_get_glyph_run_outlines_invalid_glyph_run");
  }

  auto m = NifResource<Matrix2D>::get(env, argv[2]);
  if(m == nullptr) {
    return make_result_error(env, "font_get_glyph_run_outlines_invalid_matrix");
  }

  auto path = NifResource<Path>::get(env, argv[3]);
  if(path == nullptr) {
    return make_result_error(env, "font_get_glyph_run_outlines_invalid_path");
  }

  const BLResult r =
      font->value.get_glyph_run_outlines(gr->run, m->value, path->value, nullptr, nullptr);

  if(r != BL_SUCCESS)
    return make_result_error(env, "font_get_glyph_run_outlines_failed");

  return enif_make_atom(env, "ok");
}

static inline void bltag_to_cstr(uint32_t tag, char out[5]) noexcept
{
  out[0] = char((tag >> 24) & 0xFF);
  out[1] = char((tag >> 16) & 0xFF);
  out[2] = char((tag >> 8) & 0xFF);
  out[3] = char((tag) & 0xFF);
  out[4] = '\0';
}

// font_get_feature_settings(FontRes)
ERL_NIF_TERM font_get_feature_settings(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto font = NifResource<Font>::get(env, argv[0]);
  if(font == nullptr) {
    return make_result_error(env, "font_get_feature_settings_invalid_font");
  }

  BLFontFeatureSettings settings;
  BLResult rc = bl_font_get_feature_settings(&font->value, &settings);
  if(rc != BL_SUCCESS) {
    return make_result_error(env, "font_get_feature_settings_failed");
  }

  BLFontFeatureSettingsView view;
  settings.get_view(&view);

  ERL_NIF_TERM* items = static_cast<ERL_NIF_TERM*>(alloca(sizeof(ERL_NIF_TERM) * view.size));

  for(size_t i = 0; i < view.size; ++i) {
    const BLFontFeatureItem& item = view.data[i];

    char tag_buf[5];
    bltag_to_cstr(item.tag, tag_buf);

    ERL_NIF_TERM tag_term = enif_make_string(env, tag_buf, ERL_NIF_LATIN1);
    ERL_NIF_TERM val_term = enif_make_uint(env, item.value);

    items[i] = enif_make_tuple2(env, tag_term, val_term);
  }

  ERL_NIF_TERM list = enif_make_list_from_array(env, items, view.size);
  return make_result_ok(env, list);
}

static bool tag_from_term(ErlNifEnv* env, ERL_NIF_TERM term, uint32_t* out_tag)
{
  ErlNifBinary bin;
  if(enif_inspect_binary(env, term, &bin)) {
    if(bin.size != 4)
      return false;
    const unsigned char* s = bin.data;
    *out_tag = BL_MAKE_TAG(s[0], s[1], s[2], s[3]);
    return true;
  }

  char atom[16];
  if(enif_get_atom(env, term, atom, sizeof(atom), ERL_NIF_UTF8)) {
    size_t len = std::strlen(atom);
    if(len != 4)
      return false;
    *out_tag = BL_MAKE_TAG(atom[0], atom[1], atom[2], atom[3]);
    return true;
  }

  return false;
}
// font_create_with_features(FaceRes, double size, [{Tag, IntVal}...])
ERL_NIF_TERM font_create_with_features(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 3) {
    return enif_make_badarg(env);
  }

  auto face = NifResource<FontFace>::get(env, argv[0]);
  if(face == nullptr) {
    return make_result_error(env, "font_create_with_features_invalid_resource");
  }

  double size;
  if(!enif_get_double(env, argv[1], &size)) {
    return make_result_error(env, "font_create_with_features_invalid_size");
  }

  ERL_NIF_TERM list = argv[2], head, tail;
  BLFontFeatureSettings feats;

  while(enif_get_list_cell(env, list, &head, &tail)) {
    const ERL_NIF_TERM* tup;
    int arity;
    if(!enif_get_tuple(env, head, &arity, &tup) || arity != 2) {
      return make_result_error(env, "font_create_with_features_invalid_feature_tuple");
    }

    uint32_t tag;
    if(!tag_from_term(env, tup[0], &tag)) {
      return make_result_error(env, "font_create_with_features_invalid_feature_tag");
    }

    unsigned val;
    if(!enif_get_uint(env, tup[1], &val)) {
      return make_result_error(env, "font_create_with_features_invalid_feature_value");
    }

    BLResult r = feats.set_value(tag, val);
    if(r != BL_SUCCESS) {
      return make_result_error(env, "font_create_with_features_feature_set_value_failed");
    }

    list = tail;
  }

  auto res = NifResource<Font>::alloc();

  BLResult cr =
      res->value.create_from_face(face->value, (float)size, feats, BLFontVariationSettings());
  if(cr != BL_SUCCESS) {
    res->destroy();
    return make_result_error(env, "font_create_with_features_failed");
  }

  return make_result_ok(env, NifResource<Font>::make(env, res));
}

// font_get_matrix(FontRes)
ERL_NIF_TERM font_get_matrix(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto font = NifResource<Font>::get(env, argv[0]);
  if(font == nullptr) {
    return make_result_error(env, "font_get_matrix_invalid_font");
  }

  const BLFontMatrix& m = font->value.matrix();

  ERL_NIF_TERM map = enif_make_new_map(env);
  PUT_NUM(env, map, "m00", m.m00);
  PUT_NUM(env, map, "m01", m.m01);
  PUT_NUM(env, map, "m10", m.m10);
  PUT_NUM(env, map, "m11", m.m11);

  return make_result_ok(env, map);
}

ERL_NIF_TERM font_get_glyph_bounds(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  auto res = NifResource<Font>::get(env, argv[0]);
  if(res == nullptr)
    return make_result_error(env, "font_get_glyph_bounds_invalid_font");

  BLFont& font = res->value;

  unsigned int gid_u = 0;
  if(enif_get_uint(env, argv[1], &gid_u)) {
    uint32_t glyph_id = (uint32_t)gid_u;

    BLBoxI box;
    BLResult r = font.get_glyph_bounds(&glyph_id, (intptr_t)sizeof(uint32_t), &box, 1);
    if(r != BL_SUCCESS)
      return make_result_error(env, "font_get_glyph_bounds");

    ERL_NIF_TERM box_term = enif_make_tuple4(env,
                                             enif_make_double(env, (double)box.x0),
                                             enif_make_double(env, (double)box.y0),
                                             enif_make_double(env, (double)box.x1),
                                             enif_make_double(env, (double)box.y1));

    return make_result_ok(env, box_term);
  }

  // Case 2: list of glyph ids
  if(enif_is_list(env, argv[1])) {
    // First pass: length
    unsigned int len = 0;
    if(!enif_get_list_length(env, argv[1], &len))
      return enif_make_badarg(env);

    if(len == 0) {
      // empty list -> ok, []
      return make_result_ok(env, enif_make_list(env, 0));
    }

    std::vector<uint32_t> glyphs(len);
    std::vector<BLBoxI> boxes(len);

    // Second pass: fill glyphs[]
    ERL_NIF_TERM list = argv[1];
    ERL_NIF_TERM head;
    int idx = 0;

    while(enif_get_list_cell(env, list, &head, &list)) {
      unsigned int g = 0;
      if(!enif_get_uint(env, head, &g))
        return enif_make_badarg(env);

      glyphs[idx++] = (uint32_t)g;
    }

    BLResult r =
        font.get_glyph_bounds(glyphs.data(), (intptr_t)sizeof(uint32_t), boxes.data(), len);
    if(r != BL_SUCCESS)
      return make_result_error(env, "font_get_glyph_bounds");

    // Build list of {x0,y0,x1,y1}
    ERL_NIF_TERM acc = enif_make_list(env, 0);

    for(int i = (int)len - 1; i >= 0; --i) {
      BLBoxI& b = boxes[i];

      ERL_NIF_TERM box_term = enif_make_tuple4(env,
                                               enif_make_double(env, (double)b.x0),
                                               enif_make_double(env, (double)b.y0),
                                               enif_make_double(env, (double)b.x1),
                                               enif_make_double(env, (double)b.y1));

      acc = enif_make_list_cell(env, box_term, acc);
    }

    return make_result_ok(env, acc);
  }

  // Neither int nor list -> badarg
  return enif_make_badarg(env);
}

ERL_NIF_TERM font_get_glyph_outlines(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 4) {
    return enif_make_badarg(env);
  }

  // argv[0] : Font
  auto font = NifResource<Font>::get(env, argv[0]);
  if(font == nullptr) {
    return make_result_error(env, "font_get_glyph_outlines_invalid_font");
  }

  // argv[1] : glyph id (uint)
  unsigned glyph_u32 = 0;
  if(!enif_get_uint(env, argv[1], &glyph_u32)) {
    return make_result_error(env, "font_get_glyph_outlines_invalid_glyph_id");
  }
  uint32_t glyph_id = static_cast<uint32_t>(glyph_u32);

  // argv[2] : Matrix2D
  auto matrix = NifResource<Matrix2D>::get(env, argv[2]);
  if(matrix == nullptr) {
    return make_result_error(env, "font_get_glyph_outlines_invalid_matrix");
  }

  // argv[3] : Path
  auto path = NifResource<Path>::get(env, argv[3]);
  if(path == nullptr) {
    return make_result_error(env, "font_get_glyph_outlines_invalid_path");
  }

  // For predictable semantics: clear the path before appending
  path->value.clear();

  // BLResult BLFont::get_glyph_outlines(uint32_t glyphId,
  //                                     const BLMatrix2D* m,
  //                                     BLPath* out) const noexcept;
  BLResult r = font->value.get_glyph_outlines(glyph_id, matrix->value, path->value);

  if(r != BL_SUCCESS) {
    return make_result_error(env, "font_get_glyph_outlines_failed");
  }

  // Path has been mutated in-place; we just signal success.
  return enif_make_atom(env, "ok");
}
