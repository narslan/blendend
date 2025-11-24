#pragma once
#include <blend2d/blend2d.h>
#include <cstdint>

struct Image {
  BLImage value;

  void destroy()
  {
    value.reset();
  }
};

