#pragma once
#include "../nif/nif_resource.h"
#include "erl_nif.h"

#include <blend2d/blend2d.h>
#include <string>
#include <unordered_map>
struct Color {
  BLRgba32 value;

  void destroy() noexcept
  {
    // Nothing to do; BLRgba32 has no dynamic resources.
  }
};

struct Gradient {
  BLGradient value;

  void destroy() noexcept
  {
    value.reset();
  }
};

struct Pattern {
  BLPattern value;

  void destroy() noexcept
  {
    value.reset();
  }
};

struct Style {
  // --- Fill ---
  Color* color = nullptr;
  Gradient* gradient = nullptr;
  Pattern* pattern = nullptr;
  bool has_comp_op = false;
  // --- Stroke ---
  Color* stroke_color = nullptr;
  Gradient* stroke_gradient = nullptr;
  Pattern* stroke_pattern = nullptr;
  double stroke_alpha = 1.0;
  bool stroke_alpha_set = false;

  BLStrokeOptions stroke_opts;
  bool has_stroke_opts = false;

  // --- Common ---
  double alpha = 1.0;
  BLCompOp comp_op = BL_COMP_OP_SRC_OVER;

  Style() noexcept
  {
    stroke_opts.width = 1.0;
    stroke_opts.miter_limit = 4.0;
    stroke_opts.start_cap = BL_STROKE_CAP_BUTT;
    stroke_opts.end_cap = BL_STROKE_CAP_BUTT;
    stroke_opts.join = BL_STROKE_JOIN_MITER_CLIP;
  }

  bool has_fill() const noexcept
  {
    return pattern || gradient || color;
  }

  bool has_stroke() const noexcept
  {
    // “there is stroke info here” if we either explicitly set
    // some stroke options or we set a stroke style (color/gradient).
    if(stroke_color || stroke_gradient || stroke_pattern)
      return true;
    if(has_stroke_opts)
      return true;
    return false;
  }

  // --- Apply Fill ---
  void apply_fill(BLContext* ctx) const noexcept
  {
    // precedence: pattern > gradient > color
    if(pattern) {
      ctx->set_fill_style(pattern->value);
    }
    else if(gradient) {
      ctx->set_fill_style(gradient->value);
    }
    else if(color) {
      ctx->set_fill_style(color->value);
    }
  }

  // --- Apply Stroke ---
  void apply_stroke(BLContext* ctx) const noexcept
  {
    if(has_stroke_opts)
      ctx->set_stroke_options(stroke_opts);

    if(stroke_alpha_set)
      ctx->set_stroke_alpha(stroke_alpha);

    if(stroke_pattern)
      ctx->set_stroke_style(stroke_pattern->value);
    if(stroke_color)
      ctx->set_stroke_style(stroke_color->value);
    else if(stroke_gradient)
      ctx->set_stroke_style(stroke_gradient->value);
  }

  void apply(BLContext* ctx) const noexcept
  {
    if(has_comp_op)
      ctx->set_comp_op(comp_op);
    if(alpha != 1.0)
      ctx->set_global_alpha(alpha);

    if(has_fill())
      apply_fill(ctx);
    if(has_stroke())
      apply_stroke(ctx);
  }
};

inline bool
parse_style(ErlNifEnv* env, const ERL_NIF_TERM argv[], int argc, int opts_index, Style* out)
{
  // No opts provided
  if(argc <= opts_index)
    return true;

  // Options must be a list; if not, treat as malformed
  ERL_NIF_TERM list = argv[opts_index], head, tail;
  if(!enif_is_list(env, list))
    return false;

  bool ok = true; // becomes false if any recognized key has a bad value

  while(enif_get_list_cell(env, list, &head, &tail)) {
    const ERL_NIF_TERM* tup;
    int arity;
    if(!enif_get_tuple(env, head, &arity, &tup) || arity != 2) {
      // malformed item in opts list
      ok = false;
      list = tail;
      continue;
    }

    char key[64];
    if(!enif_get_atom(env, tup[0], key, sizeof(key), ERL_NIF_UTF8)) {
      ok = false;
      list = tail;
      continue;
    }

    // --- Fill (accepts color / gradient / pattern) ---
    if(strcmp(key, "fill") == 0) {
      if(auto c = NifResource<Color>::get(env, tup[1]))
        out->color = c;
      else if(auto g = NifResource<Gradient>::get(env, tup[1]))
        out->gradient = g;
      else if(auto p = NifResource<Pattern>::get(env, tup[1]))
        out->pattern = p;
      else
        ok = false;
    }

    // --- Stroke (accepts color / gradient / pattern) ---
    else if(strcmp(key, "stroke") == 0) {
      if(auto c = NifResource<Color>::get(env, tup[1]))
        out->stroke_color = c;
      else if(auto g = NifResource<Gradient>::get(env, tup[1]))
        out->stroke_gradient = g;
      else if(auto p = NifResource<Pattern>::get(env, tup[1]))
        out->stroke_pattern = p;
      else
        ok = false;
    }
    else if(strcmp(key, "stroke_width") == 0) {
      double w;
      if(enif_get_double(env, tup[1], &w)) {
        out->stroke_opts.width = w;
        out->has_stroke_opts = true;
      }
      else {
        ok = false;
      }
    }
    else if(strcmp(key, "stroke_alpha") == 0) {
      if(enif_get_double(env, tup[1], &out->stroke_alpha))
        out->stroke_alpha_set = true;
      else
        ok = false;
    }

    // --- Caps / Joins ---
    else if(strcmp(key, "stroke_cap") == 0) {
      char cap[32];
      if(enif_get_atom(env, tup[1], cap, sizeof(cap), ERL_NIF_UTF8)) {
        uint8_t mode = BL_STROKE_CAP_BUTT;
        if(!strcmp(cap, "round"))
          mode = BL_STROKE_CAP_ROUND;
        else if(!strcmp(cap, "square"))
          mode = BL_STROKE_CAP_SQUARE;
        else if(!strcmp(cap, "round_rev"))
          mode = BL_STROKE_CAP_ROUND_REV;
        else if(!strcmp(cap, "triangle"))
          mode = BL_STROKE_CAP_TRIANGLE;
        else if(!strcmp(cap, "triangle_rev"))
          mode = BL_STROKE_CAP_TRIANGLE_REV;
        // unknown cap name → keep default (BUTT)
        out->stroke_opts.start_cap = mode;
        out->stroke_opts.end_cap = mode;
        out->has_stroke_opts = true;
      }
      else {
        ok = false;
      }
    }
    else if(strcmp(key, "stroke_join") == 0) {
      char join[32];
      if(enif_get_atom(env, tup[1], join, sizeof(join), ERL_NIF_UTF8)) {
        uint8_t mode = BL_STROKE_JOIN_MITER_CLIP;
        if(!strcmp(join, "round"))
          mode = BL_STROKE_JOIN_ROUND;
        else if(!strcmp(join, "bevel"))
          mode = BL_STROKE_JOIN_BEVEL;
        else if(!strcmp(join, "miter_bevel"))
          mode = BL_STROKE_JOIN_MITER_BEVEL;
        else if(!strcmp(join, "miter_round"))
          mode = BL_STROKE_JOIN_MITER_ROUND;
        // unknown join name → keep default (MITER_CLIP)
        out->stroke_opts.join = mode;
        out->has_stroke_opts = true;
      }
      else {
        ok = false;
      }
    }
    else if(strcmp(key, "stroke_miter_limit") == 0) {
      if(enif_get_double(env, tup[1], &out->stroke_opts.miter_limit)) {
        out->has_stroke_opts = true;
      }
      else {
        ok = false;
      }
    }

    // --- General ---
    else if(strcmp(key, "alpha") == 0) {
      if(!enif_get_double(env, tup[1], &out->alpha))
        ok = false;
    }
    else if(strcmp(key, "comp_op") == 0) {
      char op[32];
      if(enif_get_atom(env, tup[1], op, sizeof(op), ERL_NIF_UTF8)) {
        // static map once
        static const std::unordered_map<std::string, BLCompOp> comp_map = {
            {"src_over", BL_COMP_OP_SRC_OVER},
            {"src_copy", BL_COMP_OP_SRC_COPY},
            {"src_in", BL_COMP_OP_SRC_IN},
            {"src_out", BL_COMP_OP_SRC_OUT},
            {"src_atop", BL_COMP_OP_SRC_ATOP},
            {"dst_over", BL_COMP_OP_DST_OVER},
            {"dst_copy", BL_COMP_OP_DST_COPY},
            {"dst_in", BL_COMP_OP_DST_IN},
            {"dst_out", BL_COMP_OP_DST_OUT},
            {"dst_atop", BL_COMP_OP_DST_ATOP},
            {"difference", BL_COMP_OP_DIFFERENCE},
            {"multiply", BL_COMP_OP_MULTIPLY},
            {"screen", BL_COMP_OP_SCREEN},
            {"overlay", BL_COMP_OP_OVERLAY},
            {"xor", BL_COMP_OP_XOR},
            {"clear", BL_COMP_OP_CLEAR},
            {"plus", BL_COMP_OP_PLUS},
            {"minus", BL_COMP_OP_MINUS},
            {"modulate", BL_COMP_OP_MODULATE},
            {"darken", BL_COMP_OP_DARKEN},
            {"lighten", BL_COMP_OP_LIGHTEN},
            {"color_dodge", BL_COMP_OP_COLOR_DODGE},
            {"color_burn", BL_COMP_OP_COLOR_BURN},
            {"linear_burn", BL_COMP_OP_LINEAR_BURN},
            {"pin_light", BL_COMP_OP_PIN_LIGHT},
            {"hard_light", BL_COMP_OP_HARD_LIGHT},
            {"soft_light", BL_COMP_OP_SOFT_LIGHT},
            {"exclusion", BL_COMP_OP_EXCLUSION}};
        out->has_comp_op = true;
        auto it = comp_map.find(std::string(op));
        out->comp_op = (it != comp_map.end()) ? it->second : BL_COMP_OP_SRC_OVER;
      }
      else {
        ok = false;
      }
    }

    // Unknown key
    list = tail;
  }

  return ok;
}
