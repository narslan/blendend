// Generic fill template
#pragma once
#include "../canvas/canvas.h"
#include "../styles/styles.h"
#include "../text/font.h"
#include "../text/glyph_buffer.h"
#include "../text/glyph_run.h"
#include "nif_resource.h"
#include "nif_util.h"
#include <blend2d/blend2d.h>
#include <string>
#include <unordered_map>

// ----------------------------------------------------------------------------
// parse_list<T>
// ----------------------------------------------------------------------------
// Purpose: Convert an Erlang list into a std::vector<T> for specific Blend2D
//          shapes (BLPoint, BLRect, BLBox).
// Usage:   Called by draw_shape_template when ShapeT is BLArrayView<...>.
// Args:    list :: [tuple()] where tuple arity depends on T.
// Returns: vector<T>. If list/tuple decode fails mid-way, returns elements
//          parsed so far (best-effort) and stops.

template <typename T>
static std::vector<T> parse_list(ErlNifEnv* env, ERL_NIF_TERM list);

template <>
std::vector<BLPoint> parse_list<BLPoint>(ErlNifEnv* env, ERL_NIF_TERM list)
{
  std::vector<BLPoint> out;
  unsigned int len;
  if(!enif_get_list_length(env, list, &len))
    return out;
  out.reserve(len);

  ERL_NIF_TERM head, tail = list;
  for(unsigned int i = 0; i < len; i++) {
    if(!enif_get_list_cell(env, tail, &head, &tail))
      break;
    const ERL_NIF_TERM* tuple;
    int arity;
    double x, y;
    if(!enif_get_tuple(env, head, &arity, &tuple) || arity != 2 ||
       !enif_get_double(env, tuple[0], &x) || !enif_get_double(env, tuple[1], &y))
      break;
    out.emplace_back(x, y);
  }
  return out;
}

template <>
std::vector<BLRect> parse_list<BLRect>(ErlNifEnv* env, ERL_NIF_TERM list)
{
  std::vector<BLRect> out;
  unsigned int len;
  if(!enif_get_list_length(env, list, &len))
    return out;
  out.reserve(len);

  ERL_NIF_TERM head, tail = list;
  for(unsigned int i = 0; i < len; i++) {
    if(!enif_get_list_cell(env, tail, &head, &tail))
      break;
    const ERL_NIF_TERM* tuple;
    int arity;
    double x, y, w, h;
    if(!enif_get_tuple(env, head, &arity, &tuple) || arity != 4 ||
       !enif_get_double(env, tuple[0], &x) || !enif_get_double(env, tuple[1], &y) ||
       !enif_get_double(env, tuple[2], &w) || !enif_get_double(env, tuple[3], &h))
      break;
    out.emplace_back(x, y, w, h);
  }
  return out;
}

template <>
std::vector<BLBox> parse_list<BLBox>(ErlNifEnv* env, ERL_NIF_TERM list)
{
  std::vector<BLBox> out;
  unsigned int len;
  if(!enif_get_list_length(env, list, &len))
    return out;
  out.reserve(len);

  ERL_NIF_TERM head, tail = list;
  for(unsigned int i = 0; i < len; i++) {
    if(!enif_get_list_cell(env, tail, &head, &tail))
      break;
    const ERL_NIF_TERM* tuple;
    int arity;
    double x0, y0, x1, y1;
    if(!enif_get_tuple(env, head, &arity, &tuple) || arity != 4 ||
       !enif_get_double(env, tuple[0], &x0) || !enif_get_double(env, tuple[1], &y0) ||
       !enif_get_double(env, tuple[2], &x1) || !enif_get_double(env, tuple[3], &y1))
      break;
    out.emplace_back(x0, y0, x1, y1);
  }
  return out;
}

// ----------------------------------------------------------------------------
// draw_shape_template
// ----------------------------------------------------------------------------
// Purpose: Generic NIF entry for drawing a single shape OR an array of shapes,
//          with optional style application, via a BLContext member function.
// Signature:
//   draw_shape_template(env, argc, argv, &BLContext::fill_* or stroke_*)
// argv layout:
//   [0] Canvas resource
//   [1..N] numeric args OR a list (for array shapes)
//   [last?] optional opts list (style)
// Shape routing:
//   - If ShapeT == BLArrayView<BLPoint|BLRect|BLBox>:
//       argv[1] must be a list of tuples; parsed with parse_list<T> and wrapped
//       in a transient BLArrayView passed directly to ctx method.
//   - Else (single shape types BLBox/BLRect/BLLine/BLCircle/BLEllipse/BLRoundRect/BLArc/BLTriangle):
//       collects up to 8 doubles from argv[1..], validates arity, constructs ShapeT.
// Style:
//   - parse_style(...) reads options from argv; canvas->ctx.save() before apply,
//     restore() always called before return (success or error).

template <typename ShapeT>
ERL_NIF_TERM draw_shape_template(ErlNifEnv* env,
                                 int argc,
                                 const ERL_NIF_TERM argv[],
                                 BLResult (BLContext::*fn)(const ShapeT&))
{
  if(argc < 2)
    return enif_make_badarg(env);

  // ---- Canvas ----
  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "draw_shape_invalid_canvas");
  }

  // ---- Optional style ----
  ERL_NIF_TERM opts = 0;
  int numeric_argc = argc - 1;
  if(argc >= 3 && enif_is_list(env, argv[argc - 1])) {
    opts = argv[argc - 1];
    numeric_argc -= 1;
  }

  // ---- Style ----
  Style style;
  parse_style(env, argv, argc, argc - (opts ? 1 : 0), &style);

  // ---- Apply style ----
  canvas->ctx.save();
  BLResult result = BL_SUCCESS;
  style.apply(&canvas->ctx);

  // ---- Case 1: array shapes ----
  if constexpr(std::is_same_v<ShapeT, BLArrayView<BLPoint>>) {
    auto points = parse_list<BLPoint>(env, argv[1]);
    BLArrayView<BLPoint> view;
    view.reset(points.data(), points.size());
    result = (canvas->ctx.*fn)(view);
  }
  else if constexpr(std::is_same_v<ShapeT, BLArrayView<BLRect>>) {
    auto rects = parse_list<BLRect>(env, argv[1]);
    BLArrayView<BLRect> view;
    view.reset(rects.data(), rects.size());
    result = (canvas->ctx.*fn)(view);
  }
  else if constexpr(std::is_same_v<ShapeT, BLArrayView<BLBox>>) {
    auto boxes = parse_list<BLBox>(env, argv[1]);
    BLArrayView<BLBox> view;
    view.reset(boxes.data(), boxes.size());
    result = (canvas->ctx.*fn)(view);
  }

  // ---- Case 2: single shapes ----
  else {
    // Collect up to 8 doubles for the shape
    double args[8];

    for(int i = 0; i < numeric_argc; i++) {
      if(!enif_get_double(env, argv[i + 1], &args[i])) {
        canvas->ctx.restore();
        return make_result_error(env, "draw_shape_invalid_numeric_args");
      }
    }

    ShapeT shape;

    if constexpr(std::is_same_v<ShapeT, BLBox>) {
      if(numeric_argc != 4) {
        canvas->ctx.restore();
        return make_result_error(env, "draw_shape_invalid_arity");
      }
      shape = BLBox(args[0], args[1], args[2], args[3]);
    }
    else if constexpr(std::is_same_v<ShapeT, BLRect>) {
      if(numeric_argc != 4) {
        canvas->ctx.restore();
        return make_result_error(env, "draw_shape_invalid_arity");
      }
      shape = BLRect(args[0], args[1], args[2], args[3]);
    }
    else if constexpr(std::is_same_v<ShapeT, BLLine>) {
      if(numeric_argc != 4) {
        canvas->ctx.restore();
        return make_result_error(env, "draw_shape_invalid_arity");
      }
      shape = BLLine(args[0], args[1], args[2], args[3]);
    }
    else if constexpr(std::is_same_v<ShapeT, BLCircle>) {
      if(numeric_argc != 3) {
        canvas->ctx.restore();
        return make_result_error(env, "draw_shape_invalid_arity");
      }
      shape = BLCircle(args[0], args[1], args[2]);
    }
    else if constexpr(std::is_same_v<ShapeT, BLEllipse>) {
      if(numeric_argc != 4) {
        canvas->ctx.restore();
        return make_result_error(env, "draw_shape_invalid_arity");
      }
      shape = BLEllipse(args[0], args[1], args[2], args[3]);
    }
    else if constexpr(std::is_same_v<ShapeT, BLRoundRect>) {
      if(numeric_argc != 6) {
        canvas->ctx.restore();
        return make_result_error(env, "draw_shape_invalid_arity");
      }
      shape = BLRoundRect(args[0], args[1], args[2], args[3], args[4], args[5]);
    }
    else if constexpr(std::is_same_v<ShapeT, BLArc>) {
      if(numeric_argc != 6) {
        canvas->ctx.restore();
        return make_result_error(env, "draw_shape_invalid_arity");
      }
      shape = BLArc(args[0], args[1], args[2], args[3], args[4], args[5]);
    }
    else if constexpr(std::is_same_v<ShapeT, BLTriangle>) {
      if(numeric_argc != 6) {
        canvas->ctx.restore();
        return make_result_error(env, "draw_shape_invalid_arity");
      }
      shape = BLTriangle(args[0], args[1], args[2], args[3], args[4], args[5]);
    }
    else {
      canvas->ctx.restore();
      return make_result_error(env, "draw_shape_unsupported_shape");
    }

    result = (canvas->ctx.*fn)(shape);
  }

  canvas->ctx.restore();

  if(result != BL_SUCCESS)
    return make_result_error(env, "draw_shape_failed");

  return enif_make_atom(env, "ok");
}

// ----------------------------------------------------------------------------
// nif_make_resource_from_args
// ----------------------------------------------------------------------------
// Purpose: Small helper to alloc a NIF resource and construct its .value from
//          forwarded arguments.
// Usage:   nif_make_resource_from_args<ResourceT, ShapeT>(env, argv, args...)
// Returns: {:ok, resource} or {:error, "resource_alloc_failed"}.
// Notes:
//  - ResourceT must have .value field compatible with ShapeT or wrap it.
//  - No extra initialization/finalization here; rely on ResourceT's destructor
//    via NifResource<ResourceT> registration.
//  - Keep constructor args types in sync with ShapeT's constructors.

template <typename ResourceT, typename ShapeT, typename... Args>
ERL_NIF_TERM nif_make_resource_from_args(ErlNifEnv* env, const ERL_NIF_TERM argv[], Args... args)
{
  ResourceT* res = NifResource<ResourceT>::alloc();
  if(!res)
    return make_result_error(env, "resource_alloc_failed");

  res->value = ShapeT(args...);
  return make_result_ok(env, NifResource<ResourceT>::make(env, res));
}

// ----------------------------------------------------------------------------
// draw_text_or_glyph_template
// ----------------------------------------------------------------------------
// Purpose: Unified handler for text/glyph drawing (fill_* / stroke_*) with
//          optional style, chosen by FnT type (TextFn vs GlyphFn).
// Signature:
//   draw_text_or_glyph_template(env, argc, argv, fn)
// argv layout:
//   [0] Canvas resource
//   [1] Font resource
//   [2] x :: double
//   [3] y :: double
//   [4] TEXT: binary (UTF-8/bytes)   |  GLYPH: GlyphRun resource
//   [5] (optional) opts list (style)
// Dispatch:
//   - If FnT == TextFn: argv[4] must be binary; passed as BLStringView (not NUL-terminated).
//   - If FnT == GlyphFn: argv[4] must be a GlyphRun resource; run passed directly.
// Style:
//   - parse_style at index 5 when present; ctx save/apply before draw; ctx restore after.
// Errors:
//   - Returns {:error, ...} on invalid canvas/font/coords/text/glyph_run or Blend2D failure.


template <typename FnT>
ERL_NIF_TERM
draw_text_or_glyph_template(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[], FnT fn)
{
  // expect: canvas, font, x, y, (text | glyph_run) [, opts]
  if(argc < 5)
    return enif_make_badarg(env);

  // Canvas
  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  if(canvas == nullptr) {
    return make_result_error(env, "draw_text_or_glyph_invalid_canvas");
  }

  // font resource
  auto font = NifResource<Font>::get(env, argv[1]);
  if(font == nullptr) {
    return make_result_error(env, "draw_text_or_glyph_invalid_font");
  }
  if(!font->value.is_valid()) {
    return make_result_error(env, "draw_text_or_glyph_invalid_font");
  }

  // coords
  double x, y;
  if(!enif_get_double(env, argv[2], &x) || !enif_get_double(env, argv[3], &y)) {
    return make_result_error(env, "draw_text_or_glyph_invalid_coords");
  }

  // style (optional)
  if(argc > 5) {
    Style style;
    parse_style(env, argv, argc, 5, &style);
    canvas->ctx.save();
    style.apply(&canvas->ctx);
  }
  else {
    canvas->ctx.save();
  }

  BLPoint origin((double)x, (double)y);

  using TextFn =
      BLResult (BLContext::*)(const BLPoint&, const BLFontCore&, const BLStringView&) noexcept;
  using GlyphFn =
      BLResult (BLContext::*)(const BLPoint&, const BLFontCore&, const BLGlyphRun&) noexcept;

  BLResult result = BL_SUCCESS;

  if constexpr(std::is_same_v<FnT, TextFn>) {
    // TEXT variant: expect a binary as argv[4]
    ErlNifBinary text_bin;
    if(!enif_inspect_binary(env, argv[4], &text_bin)) {
      canvas->ctx.restore();
      return make_result_error(env, "draw_text_or_glyph_invalid_text");
    }

    const char* text = reinterpret_cast<const char*>(text_bin.data);
    size_t len = text_bin.size;
    result = (canvas->ctx.*fn)(origin, font->value, BLStringView{text, len});
  }
  else if constexpr(std::is_same_v<FnT, GlyphFn>) {
    // GLYPH variant: expect a GlyphRun resource at argv[4]
    auto gr = NifResource<GlyphRun>::get(env, argv[4]);
    if(gr == nullptr) {
      canvas->ctx.restore();
      return make_result_error(env, "draw_text_or_glyph_invalid_glyph_run");
    }

    const BLGlyphRun& run = gr->run;
    result = (canvas->ctx.*fn)(origin, font->value, run);
  }
  else {
    // unsupported FnT
    canvas->ctx.restore();
    return enif_make_badarg(env);
  }

  canvas->ctx.restore();

  if(result != BL_SUCCESS)
    return make_result_error(env, "draw_text_or_glyph_failed");

  return enif_make_atom(env, "ok");
}
