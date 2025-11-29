#include "blur.h"

#include <cmath>
#include <cstring>
#include <vector>

namespace {
struct BoxSizes {
  int sizes[3];
};

inline BoxSizes gaussian_to_box_sizes(double sigma)
{
  const double n = 3.0;
  double wIdeal = std::sqrt((12.0 * sigma * sigma / n) + 1.0);
  int wl = static_cast<int>(std::floor(wIdeal));
  if((wl & 1) == 0)
    wl -= 1;
  int wu = wl + 2;

  double mIdeal = (12.0 * sigma * sigma - n * wl * wl - 4.0 * n * wl - 3.0 * n) / (-4.0 * wl - 4.0);
  int m = static_cast<int>(std::round(mIdeal));

  BoxSizes bs;
  for(int i = 0; i < 3; ++i) {
    bs.sizes[i] = (i < m) ? wl : wu;
  }
  return bs;
}

inline int clamp_int(int v, int lo, int hi)
{
  if(v < lo)
    return lo;
  if(v > hi)
    return hi;
  return v;
}

struct ImgView {
  uint8_t* data;
  int w;
  int h;
  int stride;  // bytes between rows
  int channels;
};

struct BlurScratch {
  std::vector<uint8_t> buf_a; // tight-packed buffer
  std::vector<uint8_t> buf_b; // temp buffer
};

thread_local BlurScratch blur_scratch;

void box_blur_h(const ImgView& src, const ImgView& dst, int radius)
{
  const int dia = radius * 2 + 1;
  for(int y = 0; y < src.h; ++y) {
    const uint8_t* srow = src.data + static_cast<size_t>(y) * src.stride;
    uint8_t* drow = dst.data + static_cast<size_t>(y) * dst.stride;

    std::vector<int> sums(src.channels, 0);
    for(int i = -radius; i <= radius; ++i) {
      int ix = clamp_int(i, 0, src.w - 1);
      const uint8_t* p = srow + static_cast<size_t>(ix) * static_cast<size_t>(src.channels);
      for(int c = 0; c < src.channels; ++c)
        sums[c] += p[c];
    }

    for(int x = 0; x < src.w; ++x) {
      uint8_t* dst_px = drow + static_cast<size_t>(x) * static_cast<size_t>(src.channels);
      for(int c = 0; c < src.channels; ++c)
        dst_px[c] = static_cast<uint8_t>((sums[c] + dia / 2) / dia);

      int next = clamp_int(x + radius + 1, 0, src.w - 1);
      int prev = clamp_int(x - radius, 0, src.w - 1);

      const uint8_t* pNext =
          srow + static_cast<size_t>(next) * static_cast<size_t>(src.channels);
      const uint8_t* pPrev =
          srow + static_cast<size_t>(prev) * static_cast<size_t>(src.channels);

      for(int c = 0; c < src.channels; ++c)
        sums[c] += pNext[c] - pPrev[c];
    }
  }
}

void box_blur_v(const ImgView& src, const ImgView& dst, int radius)
{
  const int dia = radius * 2 + 1;
  for(int x = 0; x < src.w; ++x) {
    std::vector<int> sums(src.channels, 0);
    for(int i = -radius; i <= radius; ++i) {
      int iy = clamp_int(i, 0, src.h - 1);
      const uint8_t* p =
          src.data + static_cast<size_t>(iy) * src.stride +
          static_cast<size_t>(x) * static_cast<size_t>(src.channels);
      for(int c = 0; c < src.channels; ++c)
        sums[c] += p[c];
    }

    for(int y = 0; y < src.h; ++y) {
      uint8_t* dst_px =
          dst.data + static_cast<size_t>(y) * dst.stride +
          static_cast<size_t>(x) * static_cast<size_t>(src.channels);
      for(int c = 0; c < src.channels; ++c)
        dst_px[c] = static_cast<uint8_t>((sums[c] + dia / 2) / dia);

      int next = clamp_int(y + radius + 1, 0, src.h - 1);
      int prev = clamp_int(y - radius, 0, src.h - 1);

      const uint8_t* pNext =
          src.data + static_cast<size_t>(next) * src.stride +
          static_cast<size_t>(x) * static_cast<size_t>(src.channels);
      const uint8_t* pPrev =
          src.data + static_cast<size_t>(prev) * src.stride +
          static_cast<size_t>(x) * static_cast<size_t>(src.channels);

      for(int c = 0; c < src.channels; ++c)
        sums[c] += pNext[c] - pPrev[c];
    }
  }
}
}  // namespace

BLResult blur_image_inplace(BLImage& img, double sigma, int width, int height)
{
  if(sigma <= 0.0)
    return BL_ERROR_INVALID_VALUE;

  BLSizeI sz = img.size();
  if(sz.w == 0 || sz.h == 0)
    return BL_SUCCESS;

  BLFormat fmt = img.format();
  int channels = 0;
  switch(fmt) {
    case BL_FORMAT_PRGB32:
      channels = 4;
      break;
    case BL_FORMAT_A8:
      channels = 1;
      break;
    default:
      return BL_ERROR_INVALID_STATE;
  }

  BLImageData data{};
  BLResult r = img.get_data(&data);
  if(r != BL_SUCCESS)
    return r;

  const int eff_w = (width > 0 && width <= sz.w) ? width : sz.w;
  const int eff_h = (height > 0 && height <= sz.h) ? height : sz.h;

  const size_t row_bytes = static_cast<size_t>(eff_w) * static_cast<size_t>(channels);
  const size_t buf_bytes = row_bytes * static_cast<size_t>(eff_h);

  BlurScratch& scratch = blur_scratch;
  if(scratch.buf_a.size() < buf_bytes)
    scratch.buf_a.resize(buf_bytes);
  if(scratch.buf_b.size() < buf_bytes)
    scratch.buf_b.resize(buf_bytes);

  uint8_t* src_data = static_cast<uint8_t*>(data.pixel_data);

  // If the image is already tightly packed, work in-place in buf_a with a single copy.
  uint8_t* packed_src = scratch.buf_a.data();
  if(static_cast<int>(row_bytes) == data.stride) {
    std::memcpy(packed_src, src_data, buf_bytes);
  }
  else {
    for(int y = 0; y < eff_h; ++y) {
      std::memcpy(packed_src + static_cast<size_t>(y) * row_bytes,
                  src_data + static_cast<size_t>(y) * data.stride,
                  row_bytes);
    }
  }

  ImgView src{packed_src, eff_w, eff_h, static_cast<int>(row_bytes), channels};
  ImgView dst{scratch.buf_b.data(), eff_w, eff_h, static_cast<int>(row_bytes), channels};

  BoxSizes boxes = gaussian_to_box_sizes(sigma);
  for(int bi = 0; bi < 3; ++bi) {
    int radius = boxes.sizes[bi] / 2;
    box_blur_h(src, dst, radius);
    box_blur_v(dst, src, radius);
  }

  // Copy back into the image using its stride if needed.
  if(static_cast<int>(row_bytes) == data.stride) {
    std::memcpy(src_data, packed_src, buf_bytes);
  }
  else {
    for(int y = 0; y < eff_h; ++y) {
      std::memcpy(src_data + static_cast<size_t>(y) * data.stride,
                  packed_src + static_cast<size_t>(y) * row_bytes,
                  row_bytes);
    }
  }

  return BL_SUCCESS;
}
