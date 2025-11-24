#pragma once
#include <blend2d/blend2d.h>

struct Path {
  BLPath value;

  void destroy()
  {
    value.reset();
  }
};