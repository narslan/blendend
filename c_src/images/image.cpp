#include "image.h"
#include "blur.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"

// image_read_from_data(Binary) -> {:ok, Image} | {:error, reason}
ERL_NIF_TERM image_read_from_data(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary bin;

  if(argc != 1) {
    return enif_make_badarg(env);
  }

  if(!enif_inspect_binary(env, argv[0], &bin)) {
    return make_result_error(env, "invalid_image_data");
  }

  // Allocate the NIF resource; this default-constructs Image with a BLImage inside.
  auto img = NifResource<Image>::alloc();

  BLResult r = img->value.read_from_data(bin.data, bin.size);

  if(r != BL_SUCCESS) {
    img->destroy(); // optional; reset() clears the handle
    return make_result_error(env, "image_read_from_data_failed");
  }

  ERL_NIF_TERM res_term = NifResource<Image>::make(env, img);
  return make_result_ok(env, res_term);
}

// image_read_mask_from_data(Binary [, ChannelAtom]) -> {:ok, ImageA8} | {:error, reason}
ERL_NIF_TERM image_read_mask_from_data(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary bin;

  if(argc != 1 && argc != 2) {
    return enif_make_badarg(env);
  }

  if(!enif_inspect_binary(env, argv[0], &bin)) {
    return make_result_error(env, "invalid_image_data");
  }

  int channel_index = 2; // default to red (BGRA layout in PRGB32)
  bool use_luma = false;

  if(argc == 2) {
    char chan[16];
    if(!enif_get_atom(env, argv[1], chan, sizeof(chan), ERL_NIF_UTF8)) {
      return make_result_error(env, "image_read_mask_invalid_channel");
    }
    if(strcmp(chan, "red") == 0) channel_index = 2;
    else if(strcmp(chan, "green") == 0) channel_index = 1;
    else if(strcmp(chan, "blue") == 0) channel_index = 0;
    else if(strcmp(chan, "alpha") == 0) channel_index = 3;
    else if(strcmp(chan, "luma") == 0) { use_luma = true; }
    else return make_result_error(env, "image_read_mask_invalid_channel");
  }

  BLImage src;
  BLResult r = src.read_from_data(bin.data, bin.size);
  if(r != BL_SUCCESS) {
    return make_result_error(env, "image_read_from_data_failed");
  }

  // Ensure we have a predictable source format (PRGB32) for channel extraction.
  if(src.format() != BL_FORMAT_PRGB32) {
    r = src.convert(BL_FORMAT_PRGB32);
    if(r != BL_SUCCESS) {
      return make_result_error(env, "image_read_mask_convert_failed");
    }
  }

  BLSizeI sz = src.size();

  BLImageData srcData{};
  if(src.get_data(&srcData) != BL_SUCCESS) {
    return make_result_error(env, "image_read_mask_src_data_failed");
  }

  BLImage mask;
  r = mask.create(sz.w, sz.h, BL_FORMAT_A8);
  if(r != BL_SUCCESS) {
    return make_result_error(env, "image_read_mask_alloc_failed");
  }

  BLImageData dstData{};
  if(mask.get_data(&dstData) != BL_SUCCESS) {
    return make_result_error(env, "image_read_mask_dst_data_failed");
  }

  const uint8_t* srcPixels = static_cast<const uint8_t*>(srcData.pixel_data);
  uint8_t* dstPixels = static_cast<uint8_t*>(dstData.pixel_data);

  for(int y = 0; y < sz.h; ++y) {
    const uint8_t* srow = srcPixels + y * srcData.stride;
    uint8_t* drow = dstPixels + y * dstData.stride;
    for(int x = 0; x < sz.w; ++x) {
      if(use_luma) {
        uint8_t b = srow[x * 4 + 0];
        uint8_t g = srow[x * 4 + 1];
        uint8_t r8 = srow[x * 4 + 2];
        // integer luma approximation (0.299, 0.587, 0.114)
        uint32_t l = (54u * r8 + 183u * g + 19u * b) >> 8;
        drow[x] = static_cast<uint8_t>(l);
      }
      else {
        drow[x] = srow[x * 4 + channel_index];
      }
    }
  }

  auto img = NifResource<Image>::alloc();
  img->value = mask;

  ERL_NIF_TERM res_term = NifResource<Image>::make(env, img);
  return make_result_ok(env, res_term);
}


// image_size(Image) -> {:ok, {Width, Height}} | {:error, reason}
ERL_NIF_TERM image_size(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  auto img = NifResource<Image>::get(env, argv[0]);
  if(img == nullptr) {
    return make_result_error(env, "invalid_image_resource");
  }

  // BLSizeI: integer width/height
  BLSizeI sz = img->value.size(); // adjust to your struct member name

  ERL_NIF_TERM width = enif_make_int(env, sz.w);
  ERL_NIF_TERM height = enif_make_int(env, sz.h);
  return make_result_ok(env, enif_make_tuple2(env, width, height));
}

// image_decode_qoi(Binary) -> {:ok, {Width, Height, RGBA_Binary}} | {:error, reason}
ERL_NIF_TERM image_decode_qoi(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  ErlNifBinary bin;

  if(argc != 1) {
    return enif_make_badarg(env);
  }

  if(!enif_inspect_binary(env, argv[0], &bin)) {
    return make_result_error(env, "invalid_qoi_data");
  }

  BLImage src;
  BLResult r = src.read_from_data(bin.data, bin.size);
  if(r != BL_SUCCESS) {
    return make_result_error(env, "decode_qoi_failed");
  }

  BLSizeI sz = src.size();

  BLImage dst;
  r = dst.create(sz.w, sz.h, BL_FORMAT_PRGB32);
  if(r != BL_SUCCESS) {
    return make_result_error(env, "decode_qoi_alloc_failed");
  }

  {
    BLContext ctx(dst);
    r = ctx.blit_image(BLPointI(0, 0), src);
    ctx.end();
    if(r != BL_SUCCESS) {
      return make_result_error(env, "decode_qoi_blit_failed");
    }
  }

  BLImageData data;
  if(dst.get_data(&data) != BL_SUCCESS) {
    return make_result_error(env, "decode_qoi_data_failed");
  }

  size_t row_bytes = static_cast<size_t>(sz.w) * 4;
  size_t total_bytes = row_bytes * static_cast<size_t>(sz.h);

  ERL_NIF_TERM out_term;
  unsigned char* out = enif_make_new_binary(env, total_bytes, &out_term);

  uint8_t* src_data = static_cast<uint8_t*>(data.pixel_data);
  for(int y = 0; y < sz.h; ++y) {
    uint8_t* src_row = src_data + static_cast<size_t>(y) * data.stride;
    uint8_t* dst_row = out + static_cast<size_t>(y) * row_bytes;
    for(int x = 0; x < sz.w; ++x) {
      // BL_FORMAT_PRGB32 is stored as BGRA on little-endian; reorder to RGBA for tests
      uint8_t b = src_row[x * 4 + 0];
      uint8_t g = src_row[x * 4 + 1];
      uint8_t r8 = src_row[x * 4 + 2];
      uint8_t a = src_row[x * 4 + 3];
      dst_row[x * 4 + 0] = r8;
      dst_row[x * 4 + 1] = g;
      dst_row[x * 4 + 2] = b;
      dst_row[x * 4 + 3] = a;
    }
  }

  ERL_NIF_TERM width = enif_make_int(env, sz.w);
  ERL_NIF_TERM height = enif_make_int(env, sz.h);
  ERL_NIF_TERM data_term = out_term;
  ERL_NIF_TERM tuple = enif_make_tuple3(env, width, height, data_term);
  return make_result_ok(env, tuple);
}

// image_blur(Image, Sigma) -> {:ok, Image} | {:error, reason}
ERL_NIF_TERM image_blur(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2)
    return enif_make_badarg(env);

  auto img = NifResource<Image>::get(env, argv[0]);
  double sigma = 0.0;
  if(!img || !enif_get_double(env, argv[1], &sigma)) {
    return make_result_error(env, "image_blur_invalid_args");
  }

  if(sigma <= 0.0) {
    return make_result_error(env, "image_blur_sigma_must_be_positive");
  }

  BLFormat fmt = img->value.format();
  BLSizeI sz = img->value.size();
  BLFormat target_fmt = (fmt == BL_FORMAT_PRGB32 || fmt == BL_FORMAT_A8) ? fmt : BL_FORMAT_PRGB32;

  BLImage work;
  BLResult r = work.create(sz.w, sz.h, target_fmt);
  if(r != BL_SUCCESS) {
    return make_result_error(env, "image_blur_alloc_failed");
  }

  if(target_fmt == fmt && (fmt == BL_FORMAT_PRGB32 || fmt == BL_FORMAT_A8)) {
    // Straight copy (deep)
    BLImageData src{};
    BLImageData dst{};
    if(img->value.get_data(&src) != BL_SUCCESS || work.get_data(&dst) != BL_SUCCESS) {
      return make_result_error(env, "image_blur_data_failed");
    }
    size_t row_bytes = static_cast<size_t>(sz.w) * ((fmt == BL_FORMAT_A8) ? 1u : 4u);
    for(int y = 0; y < sz.h; ++y) {
      memcpy(static_cast<uint8_t*>(dst.pixel_data) + static_cast<size_t>(y) * dst.stride,
                  static_cast<const uint8_t*>(src.pixel_data) + static_cast<size_t>(y) * src.stride,
                  row_bytes);
    }
  }
  else {
    // Convert via blit into PRGB32 surface.
    BLContext ctx(work);
    r = ctx.blit_image(BLPointI(0, 0), img->value);
    ctx.end();
    if(r != BL_SUCCESS) {
      return make_result_error(env, "image_blur_convert_failed");
    }
  }

  r = blur_image_inplace(work, sigma);
  if(r != BL_SUCCESS) {
    return make_result_error(env, "image_blur_failed");
  }

  auto out = NifResource<Image>::alloc();
  out->value = work;
  return make_result_ok(env, NifResource<Image>::make(env, out));
}
