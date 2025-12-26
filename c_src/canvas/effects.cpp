#include "../geometries/path.h"
#include "../images/blur.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"
#include "../styles/styles.h"
#include "canvas.h"

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

  bool parse_blur_opts(
      ErlNifEnv* env, const ERL_NIF_TERM argv[], int argc, int opts_index, BlurOpts& out) {
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
        if(enif_get_tuple(env, tup[1], &arr_arity, &arr) && arr_arity == 2 &&
           enif_get_double(env, arr[0], &ox) && enif_get_double(env, arr[1], &oy)) {
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

  struct WatercolorOpts {
    double bleed_sigma = 6.0;
    double granulation = 0.18;
    double noise_scale = 0.02;
    int noise_octaves = 2;
    int seed = 1337;
    double strength = 1.0;
    double resolution = 1.0;
    bool valid = true;
  };

  struct WatercolorScratch {
    BLImage mask;
    BLImage patch;
    int w = 0;
    int h = 0;
  };

  thread_local WatercolorScratch watercolor_scratch;

  bool parse_watercolor_opts(ErlNifEnv* env, const ERL_NIF_TERM argv[], int argc, int opts_index,
                             WatercolorOpts& out) {
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

      if(strcmp(key, "bleed_sigma") == 0) {
        double v = 0.0;
        if(enif_get_double(env, tup[1], &v) && v >= 0.0) {
          out.bleed_sigma = v;
        }
        else {
          out.valid = false;
        }
      }
      else if(strcmp(key, "granulation") == 0) {
        double v = 0.0;
        if(enif_get_double(env, tup[1], &v) && v >= 0.0 && v <= 1.0) {
          out.granulation = v;
        }
        else {
          out.valid = false;
        }
      }
      else if(strcmp(key, "noise_scale") == 0) {
        double v = 0.0;
        if(enif_get_double(env, tup[1], &v) && v > 0.0) {
          out.noise_scale = v;
        }
        else {
          out.valid = false;
        }
      }
      else if(strcmp(key, "noise_octaves") == 0) {
        int v = 0;
        if(enif_get_int(env, tup[1], &v) && v >= 1 && v <= 8) {
          out.noise_octaves = v;
        }
        else {
          out.valid = false;
        }
      }
      else if(strcmp(key, "seed") == 0) {
        int v = 0;
        if(enif_get_int(env, tup[1], &v)) {
          out.seed = v;
        }
        else {
          out.valid = false;
        }
      }
      else if(strcmp(key, "strength") == 0) {
        double v = 1.0;
        if(enif_get_double(env, tup[1], &v) && v >= 0.0) {
          out.strength = v;
        }
        else {
          out.valid = false;
        }
      }
      else if(strcmp(key, "resolution") == 0) {
        double v = 1.0;
        if(enif_get_double(env, tup[1], &v) && v > 0.0 && v <= 1.0) {
          out.resolution = v;
        }
        else {
          out.valid = false;
        }
      }

      list = tail;
    }

    return out.valid;
  }

  bool is_watercolor_key(const char* key) {
    return strcmp(key, "bleed_sigma") == 0 || strcmp(key, "granulation") == 0 ||
           strcmp(key, "noise_scale") == 0 || strcmp(key, "noise_octaves") == 0 ||
           strcmp(key, "seed") == 0 || strcmp(key, "strength") == 0 || strcmp(key, "resolution") == 0;
  }

  inline uint32_t hash_u32(uint32_t x) {
    x ^= x >> 16;
    x *= 0x7feb352dU;
    x ^= x >> 15;
    x *= 0x846ca68bU;
    x ^= x >> 16;
    return x;
  }

  inline uint32_t hash_2i(int x, int y, uint32_t seed) {
    uint32_t h = seed;
    h ^= hash_u32(static_cast<uint32_t>(x) + 0x9e3779b9U + (h << 6) + (h >> 2));
    h ^= hash_u32(static_cast<uint32_t>(y) + 0x9e3779b9U + (h << 6) + (h >> 2));
    return hash_u32(h);
  }

  inline float rand01_2i(int x, int y, uint32_t seed) {
    const uint32_t h = hash_2i(x, y, seed);
    return static_cast<float>((h >> 8) & 0x00FFFFFFU) * (1.0f / 16777216.0f);
  }

  inline float smoothstep(float t) {
    return t * t * (3.0f - 2.0f * t);
  }

  inline float lerp(float a, float b, float t) {
    return a + (b - a) * t;
  }

  inline float clamp01(float v) {
    if(v < 0.0f)
      return 0.0f;
    if(v > 1.0f)
      return 1.0f;
    return v;
  }

  float value_noise2(float x, float y, uint32_t seed) {
    const int x0 = static_cast<int>(std::floor(x));
    const int y0 = static_cast<int>(std::floor(y));
    const int x1 = x0 + 1;
    const int y1 = y0 + 1;

    const float tx = x - static_cast<float>(x0);
    const float ty = y - static_cast<float>(y0);
    const float u = smoothstep(tx);
    const float v = smoothstep(ty);

    const float v00 = rand01_2i(x0, y0, seed) * 2.0f - 1.0f;
    const float v10 = rand01_2i(x1, y0, seed) * 2.0f - 1.0f;
    const float v01 = rand01_2i(x0, y1, seed) * 2.0f - 1.0f;
    const float v11 = rand01_2i(x1, y1, seed) * 2.0f - 1.0f;

    const float a = lerp(v00, v10, u);
    const float b = lerp(v01, v11, u);
    return lerp(a, b, v);
  }

  float fbm_value_noise2(float x, float y, uint32_t seed, int octaves) {
    float sum = 0.0f;
    float amp = 1.0f;
    float freq = 1.0f;
    float norm = 0.0f;

    for(int i = 0; i < octaves; ++i) {
      sum += value_noise2(x * freq, y * freq, seed + static_cast<uint32_t>(i) * 1013U) * amp;
      norm += amp;
      amp *= 0.5f;
      freq *= 2.0f;
    }

    if(norm <= 0.0f)
      return 0.0f;
    return sum / norm;
  }

} // namespace

// canvas_blur_path(canvas, path, sigma, opts \\ [])
ERL_NIF_TERM canvas_blur_path(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
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

  // Expand bounds to fit stroke thickness, blur radius (3*sigma), and user offsets.
  const double stroke_pad =
      (opts.stroke && style.has_stroke()) ? std::max(0.0, style.stroke_opts.width * 0.5) : 0.0;
  const double blur_pad = std::ceil(std::max(0.0, sigma * 3.0));
  const double pad_x = blur_pad + stroke_pad + std::abs(opts.offset_x);
  const double pad_y = blur_pad + stroke_pad + std::abs(opts.offset_y);

  const double width_d = bbox.x1 - bbox.x0 + pad_x * 2.0;
  const double height_d = bbox.y1 - bbox.y0 + pad_y * 2.0;

  // Optionally downscale for cheaper blur, then scale back on blit.
  const double scale = std::max(0.0, std::min(opts.resolution, 1.0));
  const int w = static_cast<int>(std::ceil(std::max(1.0, width_d * scale)));
  const int h = static_cast<int>(std::ceil(std::max(1.0, height_d * scale)));

  BlurImageScratch& scratch = blur_image_scratch;
  BLResult r = BL_SUCCESS;
  // Reuse a thread-local scratch image sized for the current blur.
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
  // Center the path in the padded scratch image and apply optional offset/scale.
  tmp_ctx.translate((pad_x - bbox.x0 + opts.offset_x) * scale,
                    (pad_y - bbox.y0 + opts.offset_y) * scale);
  tmp_ctx.scale(scale);
  style.apply(&tmp_ctx);

  if(opts.fill)
    tmp_ctx.fill_path(path->value);
  if(opts.stroke)
    tmp_ctx.stroke_path(path->value);

  tmp_ctx.restore();
  tmp_ctx.end();

  // Blur the rasterized patch; sigma is scaled with the raster scale.
  const double sigma_scaled = sigma * scale;
  r = blur_image_inplace(scratch.img, sigma_scaled, w, h);
  if(r != BL_SUCCESS) {
    return make_result_error(env, "canvas_blur_path_blur_failed");
  }

  const int dst_x = static_cast<int>(std::floor(bbox.x0 - pad_x));
  const int dst_y = static_cast<int>(std::floor(bbox.y0 - pad_y));

  canvas->ctx.save();
  // Preserve caller composition settings when drawing the blurred patch.
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

// canvas_watercolor_fill_path(canvas, path, opts \\ [])
ERL_NIF_TERM canvas_watercolor_fill_path(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]) {
  if(argc < 2)
    return enif_make_badarg(env);

  auto canvas = NifResource<Canvas>::get(env, argv[0]);
  auto path = NifResource<Path>::get(env, argv[1]);
  if(!canvas || !path) {
    return make_result_error(env, "canvas_watercolor_fill_path_invalid_args");
  }

  WatercolorOpts opts{};
  if(!parse_watercolor_opts(env, argv, argc, 2, opts)) {
    return make_result_error(env, "canvas_watercolor_fill_path_invalid_opts");
  }

  // Filter out watercolor-specific keys before parsing style.
  ERL_NIF_TERM style_list = enif_make_list(env, 0);
  if(argc >= 3) {
    ERL_NIF_TERM list = argv[2], head, tail;
    std::vector<ERL_NIF_TERM> style_terms;

    while(enif_get_list_cell(env, list, &head, &tail)) {
      const ERL_NIF_TERM* tup;
      int arity;
      if(enif_get_tuple(env, head, &arity, &tup) && arity == 2) {
        char key[64];
        if(enif_get_atom(env, tup[0], key, sizeof(key), ERL_NIF_UTF8)) {
          if(is_watercolor_key(key)) {
            // skip
          }
          else {
            style_terms.push_back(head);
          }
        }
      }
      list = tail;
    }

    style_list = enif_make_list(env, 0);
    for(auto it = style_terms.rbegin(); it != style_terms.rend(); ++it) {
      style_list = enif_make_list_cell(env, *it, style_list);
    }
  }

  ERL_NIF_TERM argv_style[3] = {argv[0], argv[1], style_list};

  Style style{};
  if(!parse_style(env, argv_style, 3, 2, &style)) {
    return make_result_error(env, "canvas_watercolor_fill_path_invalid_style");
  }

  BLBox bbox{};
  if(path->value.get_bounding_box(&bbox) != BL_SUCCESS) {
    return make_result_error(env, "canvas_watercolor_fill_path_bounds_failed");
  }

  const double bleed_pad = std::ceil(std::max(0.0, opts.bleed_sigma * 3.0));
  const double pad_x = bleed_pad;
  const double pad_y = bleed_pad;

  const double width_d = bbox.x1 - bbox.x0 + pad_x * 2.0;
  const double height_d = bbox.y1 - bbox.y0 + pad_y * 2.0;

  const double scale = std::max(0.0, std::min(opts.resolution, 1.0));
  const int w = static_cast<int>(std::ceil(std::max(1.0, width_d * scale)));
  const int h = static_cast<int>(std::ceil(std::max(1.0, height_d * scale)));

  WatercolorScratch& scratch = watercolor_scratch;
  BLResult r = BL_SUCCESS;
  if(scratch.w != w || scratch.h != h || scratch.w <= 0 || scratch.h <= 0) {
    scratch.mask.reset();
    scratch.patch.reset();

    r = scratch.mask.create(w, h, BL_FORMAT_A8);
    if(r != BL_SUCCESS) {
      return make_result_error(env, "canvas_watercolor_fill_path_alloc_failed");
    }

    r = scratch.patch.create(w, h, BL_FORMAT_PRGB32);
    if(r != BL_SUCCESS) {
      return make_result_error(env, "canvas_watercolor_fill_path_alloc_failed");
    }

    scratch.w = w;
    scratch.h = h;
  }

  // Rasterize the path into an A8 mask.
  {
    BLContextCreateInfo ci{};
    BLContext tmp_ctx;
    r = tmp_ctx.begin(scratch.mask, &ci);
    if(r != BL_SUCCESS) {
      return make_result_error(env, "canvas_watercolor_fill_path_ctx_failed");
    }

    tmp_ctx.clear_all();
    tmp_ctx.save();
    tmp_ctx.translate((pad_x - bbox.x0) * scale, (pad_y - bbox.y0) * scale);
    tmp_ctx.scale(scale);
    tmp_ctx.set_fill_style(BLRgba32(0xFFFFFFFFu));
    tmp_ctx.fill_path(path->value);
    tmp_ctx.restore();
    tmp_ctx.end();
  }

  if(opts.bleed_sigma > 0.0) {
    const double sigma_scaled = opts.bleed_sigma * scale;
    r = blur_image_inplace(scratch.mask, sigma_scaled, w, h);
    if(r != BL_SUCCESS) {
      return make_result_error(env, "canvas_watercolor_fill_path_blur_failed");
    }
  }

  // Fill a color patch in world-space, then mask it by multiplying with the A8 mask (plus granulation).
  {
    BLContextCreateInfo ci{};
    BLContext tmp_ctx;
    r = tmp_ctx.begin(scratch.patch, &ci);
    if(r != BL_SUCCESS) {
      return make_result_error(env, "canvas_watercolor_fill_path_ctx_failed");
    }

    tmp_ctx.clear_all();
    tmp_ctx.save();
    tmp_ctx.translate((pad_x - bbox.x0) * scale, (pad_y - bbox.y0) * scale);
    tmp_ctx.scale(scale);

    // Apply only fill-related style and global alpha when producing the patch.
    if(style.alpha != 1.0)
      tmp_ctx.set_global_alpha(style.alpha);
    if(style.has_fill())
      style.apply_fill(&tmp_ctx);

    const double rect_x = bbox.x0 - pad_x;
    const double rect_y = bbox.y0 - pad_y;
    tmp_ctx.fill_rect(BLRect(rect_x, rect_y, width_d, height_d));
    tmp_ctx.restore();
    tmp_ctx.end();

    BLImageData mask_data{};
    BLImageData patch_data{};
    if(scratch.mask.get_data(&mask_data) != BL_SUCCESS || scratch.patch.get_data(&patch_data) != BL_SUCCESS) {
      return make_result_error(env, "canvas_watercolor_fill_path_data_failed");
    }

    const float noise_scale = static_cast<float>(opts.noise_scale);
    const float granulation = static_cast<float>(opts.granulation);
    const float strength = static_cast<float>(opts.strength);
    const uint32_t seed = static_cast<uint32_t>(opts.seed);

    auto* mask_px = static_cast<uint8_t*>(mask_data.pixel_data);
    auto* patch_px = static_cast<uint8_t*>(patch_data.pixel_data);

    const uint32_t seed_x = hash_u32(seed ^ 0xA1B2C3D4u);
    const uint32_t seed_y = hash_u32(seed ^ 0x31415926u);
    const float off_x = static_cast<float>(seed_x & 0x3FFu) * 0.25f;
    const float off_y = static_cast<float>(seed_y & 0x3FFu) * 0.25f;

    for(int yy = 0; yy < h; ++yy) {
      uint8_t* mask_row = mask_px + static_cast<size_t>(yy) * mask_data.stride;
      uint8_t* patch_row = patch_px + static_cast<size_t>(yy) * patch_data.stride;

      for(int xx = 0; xx < w; ++xx) {
        uint8_t m = mask_row[xx];
        if(m == 0) {
          patch_row[xx * 4 + 0] = 0;
          patch_row[xx * 4 + 1] = 0;
          patch_row[xx * 4 + 2] = 0;
          patch_row[xx * 4 + 3] = 0;
          continue;
        }

        float mf = static_cast<float>(m) / 255.0f;
        if(granulation > 0.0f) {
          // Granulation is applied as an attenuation only (avoids saturated "clumps").
          // Noise is sampled in patch pixel-space for stability across `resolution`.
          const float n = fbm_value_noise2((static_cast<float>(xx) + off_x) * noise_scale,
                                           (static_cast<float>(yy) + off_y) * noise_scale,
                                           seed,
                                           opts.noise_octaves);
          const float paper = 0.5f + 0.5f * n; // [0..1]
          const float factor = (1.0f - granulation) + granulation * clamp01(paper);
          mf *= factor;
        }
        mf *= strength;
        mf = clamp01(mf);

        const int a = static_cast<int>(mf * 255.0f + 0.5f);
        const uint8_t mm = static_cast<uint8_t>(a);

        uint8_t* px = patch_row + xx * 4;
        px[0] = static_cast<uint8_t>((static_cast<int>(px[0]) * mm + 127) / 255);
        px[1] = static_cast<uint8_t>((static_cast<int>(px[1]) * mm + 127) / 255);
        px[2] = static_cast<uint8_t>((static_cast<int>(px[2]) * mm + 127) / 255);
        px[3] = static_cast<uint8_t>((static_cast<int>(px[3]) * mm + 127) / 255);
      }
    }
  }

  const int dst_x = static_cast<int>(std::floor(bbox.x0 - pad_x));
  const int dst_y = static_cast<int>(std::floor(bbox.y0 - pad_y));

  canvas->ctx.save();
  if(style.has_comp_op)
    canvas->ctx.set_comp_op(style.comp_op);

  const int dst_w = static_cast<int>(std::ceil(std::max(1.0, width_d)));
  const int dst_h = static_cast<int>(std::ceil(std::max(1.0, height_d)));

  r = canvas->ctx.blit_image(BLRectI(dst_x, dst_y, dst_w, dst_h), scratch.patch);
  canvas->ctx.restore();

  if(r != BL_SUCCESS) {
    return make_result_error(env, "canvas_watercolor_fill_path_blit_failed");
  }

  return enif_make_atom(env, "ok");
}
