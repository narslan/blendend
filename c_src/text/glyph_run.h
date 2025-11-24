// glyph_run.h
#pragma once

#include <blend2d/blend2d.h>
#include <erl_nif.h>
#include "glyph_buffer.h"
#include "../nif/nif_resource.h"

// - BLGlyphRun is not an owning structure.
// - It just points to shaped data that typically lives in a BLGlyphBuffer.
// - That means: if the buffer goes away or is reshaped, the run becomes invalid.
// - So our NIF resource must keep the *glyph buffer* resource alive.

struct GlyphRun {
  BLGlyphRun run{};
  GlyphBuffer* owner = nullptr;  // the resource that actually owns the data

  void destroy() noexcept {
    // When Erlang GC drops this resource, we must release the kept
    // reference to the underlying glyph buffer so it can also be GC'd.
    if(owner) {
      enif_release_resource(owner);
      owner = nullptr;
    }
  }
};
