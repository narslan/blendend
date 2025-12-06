#pragma once
#include <blend2d/blend2d.h>
#include <erl_nif.h>

struct FontFace {
  BLFontFace value;
  BLFontData data;             // reference-counted font data handle
  ErlNifEnv* bin_env = nullptr; // private env holding the original binary term
  ERL_NIF_TERM bin_term = 0;    // the copied binary term (lives in bin_env)

  void destroy() noexcept
  {
    value.reset();
    data.reset();
    if(bin_env) {
      enif_free_env(bin_env);
      bin_env = nullptr;
    }
    bin_term = 0;
  }
};

struct Font {
  BLFont value;
  FontFace* owner = nullptr; // keep face alive while font lives

  void destroy()
  {
    if(owner) {
      enif_release_resource(owner);
      owner = nullptr;
    }
    value.reset();
  }
};
