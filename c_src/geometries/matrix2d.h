#pragma once

#include <blend2d/blend2d.h>
#include <erl_nif.h>

struct Matrix2D {
  BLMatrix2D value;

  Matrix2D() noexcept
  {
    value.reset();
  }
  void destroy() noexcept
  {
    // nothing to free: BLMatrix2D has no heap
  }
};