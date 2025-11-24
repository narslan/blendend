#pragma once
#include <blend2d/blend2d.h>

struct GlyphBuffer {
  BLGlyphBuffer value;

  void destroy() noexcept
  {
    value.reset();
  }
};