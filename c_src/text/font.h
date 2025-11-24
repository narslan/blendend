#pragma once
#include <blend2d/blend2d.h>

struct FontFace {
  BLFontFace value;

  void destroy() noexcept
  {
    value.reset();
  }
};

struct Font {
  BLFont value;

  void destroy()
  {
    value.reset();
  }
};
