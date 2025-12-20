#pragma once
#include <cstdint>
#include <erl_nif.h>

struct RandState {
  uint64_t s[4] = {0, 0, 0, 0};

  void destroy() {}
};

ERL_NIF_TERM rand_new(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
ERL_NIF_TERM rand_normal_batch(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[]);
