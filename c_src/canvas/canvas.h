#pragma once
#include <blend2d/blend2d.h>
#include <cstring>
#include <erl_nif.h>
#include <string>

struct Canvas {
  BLImage img;
  BLContext ctx;

  void destroy()
  {
    ctx.end();
    ctx.reset();
    img.reset();
  }
};
