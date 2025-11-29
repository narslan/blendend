#include "canvas.h"
#include "../geometries/path.h"
#include "../styles/styles.h"
#include "../images/blur.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"

#include <algorithm>
#include <blend2d/blend2d.h>
#include <cmath>
#include <cstring>
#include <vector>

namespace {
struct BlurOpts {
  bool fill = true;
  bool stroke = false;
  double offset_x = 0.0;
  double offset_y = 0.0;
  bool valid = true;
  bool mode_set = false;
  double resolution = 1.0;
};

struct BlurImageScratch {
  BLImage img;
  int w = 0;
  int h = 0;
};

thread_local BlurImageScratch blur_image_scratch;

bool parse_blur_opts(ErlNifEnv* env, const ERL_NIF_TERM argv[], int argc, int opts_index, BlurOpts& out)
{
  if(argc <= opts_index)
    return true;

  ERL_NIF_TERM list = argv[opts_index], head, tail;
  if(!enif_is_list(env, list))
    return true;

  while(enif_get_list_cell(env, list, &head, &tail)) {
    const ERL_NIF_TERM* tup;
    int arity;
    if(!enif_get_tuple(env, head, &arity, &tup) || arity != 2) {
      list = tail;
      continue;
    }

    char key[64];
    if(!enif_get_atom(env, tup[0], key, sizeof(key), ERL_NIF_UTF8)) {
      list = tail;
      continue;
    }

    if(strcmp(key, "mode") == 0) {
      char val[32];
      if(enif_get_atom(env, tup[1], val, sizeof(val), ERL_NIF_UTF8)) {
        if(strcmp(val, "fill") == 0) {
          out.fill = true;
          out.stroke = false;
          out.mode_set = true;
        }
        else if(strcmp(val, "stroke") == 0) {
          out.fill = false;
          out.stroke = true;
          out.mode_set = true;
        }
        else if(strcmp(val, "fill_and_stroke") == 0 || strcmp(val, "both") == 0) {
          out.fill = true;
          out.stroke = true;
          out.mode_set = true;
        }
        else {
          out.valid = false;
        }
      }
      else {
        out.valid = false;
      }
    }
    else if(strcmp(key, "offset") == 0) {
      const ERL_NIF_TERM* arr;
      int arr_arity;
      double ox, oy;
      if(enif_get_tuple(env, tup[1], &arr_arity, &arr) && arr_arity == 2 && enif_get_double(env, arr[0], &ox) &&
         enif_get_double(env, arr[1], &oy)) {
        out.offset_x = ox;
        out.offset_y = oy;
      }
      else {
        out.valid = false;
      }
    }
    else if(strcmp(key, "resolution") == 0) {
      double res = 1.0;
      if(enif_get_double(env, tup[1], &res) && res > 0.0 && res <= 1.0) {
        out.resolution = res;
      }
      else {
        out.valid = false;
      }
    }

    list = tail;
  }

  return out.valid;
}

} // namespace

// canvas_blur_path(canvas, path, sigma, opts \\ [])
ERL_NIF_TERM canvas_blur_path(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc < 3)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  auto path = NifResource<Path>::get(env, argv[1]);
  double sigma = 0.0;
  if(!canvas || !path || !enif_get_double(env, argv[2], &sigma)) {
    return make_result_error(env, "canvas_blur_path_invalid_args");
  }

  if(sigma <= 0.0)
    return make_result_error(env, "canvas_blur_path_sigma_must_be_positive");

  BlurOpts opts{};
  if(!parse_blur_opts(env, argv, argc, 3, opts)) {
    return make_result_error(env, "canvas_blur_path_invalid_opts");
  }

  // Filter out blur-specific keys before parsing style.
  ERL_NIF_TERM style_list = enif_make_list(env, 0);
  if(argc >= 4) {
    ERL_NIF_TERM list = argv[3], head, tail;
    std::vector<ERL_NIF_TERM> style_terms;

    while(enif_get_list_cell(env, list, &head, &tail)) {
      const ERL_NIF_TERM* tup;
      int arity;
      if(enif_get_tuple(env, head, &arity, &tup) && arity == 2) {
        char key[64];
        if(enif_get_atom(env, tup[0], key, sizeof(key), ERL_NIF_UTF8)) {
          if(strcmp(key, "mode") == 0 || strcmp(key, "offset") == 0) {
            // skip blur-specific keys
          }
          else {
            style_terms.push_back(head);
          }
        }
      }
      list = tail;
    }

    // reconstruct list in original order
    style_list = enif_make_list(env, 0);
    for(auto it = style_terms.rbegin(); it != style_terms.rend(); ++it) {
      style_list = enif_make_list_cell(env, *it, style_list);
    }
  }

  ERL_NIF_TERM argv_style[4];
  memcpy(argv_style, argv, sizeof(argv_style));
  argv_style[3] = style_list;

  Style style{};
  if(!parse_style(env, argv_style, argc, 3, &style)) {
    return make_result_error(env, "canvas_blur_path_invalid_style");
  }

  if(!opts.mode_set) {
    opts.fill = style.has_fill();
    opts.stroke = style.has_stroke();
    if(!opts.fill && !opts.stroke) {
      opts.fill = true;
    }
  }

  BLBox bbox{};
  if(path->value.get_bounding_box(&bbox) != BL_SUCCESS) {
    return make_result_error(env, "canvas_blur_path_bounds_failed");
  }

  const double stroke_pad =
      (opts.stroke && style.has_stroke()) ? std::max(0.0, style.stroke_opts.width * 0.5) : 0.0;
  const double blur_pad = std::ceil(std::max(0.0, sigma * 3.0));
  const double pad_x = blur_pad + stroke_pad + std::abs(opts.offset_x);
  const double pad_y = blur_pad + stroke_pad + std::abs(opts.offset_y);

  const double width_d = bbox.x1 - bbox.x0 + pad_x * 2.0;
  const double height_d = bbox.y1 - bbox.y0 + pad_y * 2.0;

  const double scale = std::max(0.0, std::min(opts.resolution, 1.0));
  const int w = static_cast<int>(std::ceil(std::max(1.0, width_d * scale)));
  const int h = static_cast<int>(std::ceil(std::max(1.0, height_d * scale)));

  BlurImageScratch& scratch = blur_image_scratch;
  BLResult r = BL_SUCCESS;
  if(scratch.w != w || scratch.h != h || scratch.w <= 0 || scratch.h <= 0) {
    scratch.img.reset();
    r = scratch.img.create(w, h, BL_FORMAT_PRGB32);
    if(r != BL_SUCCESS) {
      return make_result_error(env, "canvas_blur_path_alloc_failed");
    }
    scratch.w = w;
    scratch.h = h;
  }

  BLContextCreateInfo ci{};
  BLContext tmp_ctx;
  r = tmp_ctx.begin(scratch.img, &ci);
  if(r != BL_SUCCESS) {
    return make_result_error(env, "canvas_blur_path_ctx_failed");
  }

  tmp_ctx.clear_all();
  tmp_ctx.save();
  tmp_ctx.translate((pad_x - bbox.x0 + opts.offset_x) * scale, (pad_y - bbox.y0 + opts.offset_y) * scale);
  tmp_ctx.scale(scale);
  style.apply(&tmp_ctx);

  if(opts.fill)
    tmp_ctx.fill_path(path->value);
  if(opts.stroke)
    tmp_ctx.stroke_path(path->value);

  tmp_ctx.restore();
  tmp_ctx.end();

  const double sigma_scaled = sigma * scale;
  r = blur_image_inplace(scratch.img, sigma_scaled, w, h);
  if(r != BL_SUCCESS) {
    return make_result_error(env, "canvas_blur_path_blur_failed");
  }

  const int dst_x = static_cast<int>(std::floor(bbox.x0 - pad_x));
  const int dst_y = static_cast<int>(std::floor(bbox.y0 - pad_y));

  canvas->ctx.save();
  if(style.has_comp_op)
    canvas->ctx.set_comp_op(style.comp_op);
  const int dst_w = static_cast<int>(std::ceil(std::max(1.0, width_d)));
  const int dst_h = static_cast<int>(std::ceil(std::max(1.0, height_d)));
  r = canvas->ctx.blit_image(BLRectI(dst_x, dst_y, dst_w, dst_h), scratch.img);
  canvas->ctx.restore();

  if(r != BL_SUCCESS) {
    return make_result_error(env, "canvas_blur_path_blit_failed");
  }

  return enif_make_atom(env, "ok");
}
