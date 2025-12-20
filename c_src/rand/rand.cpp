#include "rand.h"
#include "ziggurat_tables.h"
#include "../nif/nif_resource.h"
#include "../nif/nif_util.h"

#include <cmath>
#include <cstddef>
#include <limits>

namespace {
constexpr uint64_t kMaxInt63 = 0x7fffffffffffffffULL;
constexpr uint64_t kPow2_63_u = 0x8000000000000000ULL;
constexpr double kPow2_63 = 9223372036854775808.0;

inline uint64_t rotl(const uint64_t x, int k)
{
  return (x << k) | (x >> (64 - k));
}

inline uint64_t splitmix64(uint64_t& seed)
{
  uint64_t z = (seed += 0x9E3779B97F4A7C15ULL);
  z = (z ^ (z >> 30)) * 0xBF58476D1CE4E5B9ULL;
  z = (z ^ (z >> 27)) * 0x94D049BB133111EBULL;
  return z ^ (z >> 31);
}

inline void rand_seed(RandState* state, uint64_t seed)
{
  for(int i = 0; i < 4; ++i) {
    state->s[i] = splitmix64(seed);
  }
}

inline uint64_t rand_u64(RandState* state)
{
  const uint64_t result = rotl(state->s[1] * 5ULL, 7) * 9ULL;
  const uint64_t t = state->s[1] << 17;

  state->s[2] ^= state->s[0];
  state->s[3] ^= state->s[1];
  state->s[1] ^= state->s[2];
  state->s[0] ^= state->s[3];
  state->s[2] ^= t;
  state->s[3] = rotl(state->s[3], 45);

  return result;
}

inline uint64_t rand_u63(RandState* state)
{
  return rand_u64(state) & kMaxInt63;
}

inline uint64_t sum_u1_udiff(uint64_t u1, int64_t udiff)
{
  return udiff >= 0 ? u1 + static_cast<uint64_t>(udiff)
                    : u1 - static_cast<uint64_t>(-udiff);
}

inline double sample_x(const double* xj, uint64_t u)
{
  return xj[0] * kPow2_63 + (xj[-1] - xj[0]) * static_cast<double>(u);
}

inline double sample_y(const double* y, uint8_t i, uint64_t u)
{
  return y[i - 1] * kPow2_63 + (y[i] - y[i - 1]) * static_cast<double>(u);
}

inline uint8_t norm_sample_A(RandState* state)
{
  const int64_t r = static_cast<int64_t>(rand_u64(state));
  const uint8_t j = static_cast<uint8_t>(r);
  return r >= blendend_rand::kNormIpmf[j] ? blendend_rand::kNormMap[j] : j;
}

inline uint8_t exp_sample_A(RandState* state)
{
  const int64_t r = static_cast<int64_t>(rand_u64(state));
  const uint8_t j = static_cast<uint8_t>(r);
  return r >= blendend_rand::kExpIpmf[j] ? blendend_rand::kExpMap[j] : j;
}

inline double exp_overhang(RandState* state, uint8_t j)
{
  const double* xj = blendend_rand::kExpX + j;
  const double* y = blendend_rand::kExpY;

  uint64_t u1 = rand_u63(state);
  int64_t u_diff = static_cast<int64_t>(rand_u63(state)) - static_cast<int64_t>(u1);
  if(u_diff < 0) {
    u_diff = -u_diff;
    u1 -= static_cast<uint64_t>(u_diff);
  }

  static constexpr int64_t kExpMaxIE = 853965788476313639LL;
  const double x = sample_x(xj, u1);
  if(u_diff >= kExpMaxIE) {
    return x;
  }

  const uint64_t sum = u1 + static_cast<uint64_t>(u_diff);
  const double y_sample = sample_y(y, j, kPow2_63_u - sum);
  if(y_sample <= std::exp(-x)) {
    return x;
  }

  return exp_overhang(state, j);
}

inline double exponential(RandState* state)
{
  const uint64_t r = rand_u64(state);
  const uint8_t i = static_cast<uint8_t>(r);
  if(i < blendend_rand::kExpLayers) {
    return blendend_rand::kExpX[i] * static_cast<double>(r & kMaxInt63);
  }

  const uint8_t j = exp_sample_A(state);
  return j > 0 ? exp_overhang(state, j) : blendend_rand::kExpX0 + exponential(state);
}

inline double normal(RandState* state)
{
  uint64_t u1 = rand_u64(state);
  const uint8_t i = static_cast<uint8_t>(u1);
  if(i < blendend_rand::kNormBins) {
    return blendend_rand::kNormX[i] * static_cast<double>(static_cast<int64_t>(u1));
  }

  u1 &= kMaxInt63;
  const double sign = (u1 & 0x100) ? 1.0 : -1.0;
  const uint8_t j = norm_sample_A(state);
  const double* xj = blendend_rand::kNormX + j;

  double x = 0.0;
  if(j > blendend_rand::kNormJInflection) {
    for(;;) {
      x = sample_x(xj, u1);
      int64_t u_diff = static_cast<int64_t>(rand_u63(state)) - static_cast<int64_t>(u1);
      if(u_diff >= 0) {
        break;
      }
      if(u_diff >= -blendend_rand::kNormMaxIE) {
        const uint64_t sum = sum_u1_udiff(u1, u_diff);
        const double y = sample_y(blendend_rand::kNormY, j, kPow2_63_u - sum);
        if(y < std::exp(-0.5 * x * x)) {
          break;
        }
      }
      u1 = rand_u63(state);
    }
  }
  else if(j == 0) {
    do {
      x = exponential(state) / blendend_rand::kNormX0;
    } while(exponential(state) < 0.5 * x * x);
    x += blendend_rand::kNormX0;
  }
  else if(j < blendend_rand::kNormJInflection) {
    for(;;) {
      int64_t u_diff = static_cast<int64_t>(rand_u63(state)) - static_cast<int64_t>(u1);
      if(u_diff < 0) {
        u_diff = -u_diff;
        u1 -= static_cast<uint64_t>(u_diff);
      }
      x = sample_x(xj, u1);
      if(u_diff > blendend_rand::kNormMinIE) {
        break;
      }
      const uint64_t sum = u1 + static_cast<uint64_t>(u_diff);
      const double y = sample_y(blendend_rand::kNormY, j, kPow2_63_u - sum);
      if(y < std::exp(-0.5 * x * x)) {
        break;
      }
      u1 = rand_u63(state);
    }
  }
  else {
    for(;;) {
      x = sample_x(xj, u1);
      const double y = sample_y(blendend_rand::kNormY, j, rand_u63(state));
      if(y < std::exp(-0.5 * x * x)) {
        break;
      }
      u1 = rand_u63(state);
    }
  }

  return sign * x;
}
} // namespace

ERL_NIF_TERM rand_new(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 1) {
    return enif_make_badarg(env);
  }

  uint64_t seed = 0;
  if(!enif_get_uint64(env, argv[0], &seed)) {
    int64_t signed_seed = 0;
    if(!enif_get_int64(env, argv[0], &signed_seed)) {
      return make_result_error(env, "rand_new_invalid_seed");
    }
    seed = static_cast<uint64_t>(signed_seed);
  }

  auto rng = NifResource<RandState>::alloc();
  if(!rng) {
    return make_result_error(env, "rand_new_alloc_failed");
  }

  rand_seed(rng, seed);
  return make_result_ok(env, NifResource<RandState>::make(env, rng));
}

ERL_NIF_TERM rand_normal_batch(ErlNifEnv* env, int argc, const ERL_NIF_TERM argv[])
{
  if(argc != 2) {
    return enif_make_badarg(env);
  }

  auto rng = NifResource<RandState>::get(env, argv[0]);
  if(!rng) {
    return make_result_error(env, "rand_invalid_state");
  }

  unsigned int count = 0;
  if(!enif_get_uint(env, argv[1], &count)) {
    return make_result_error(env, "rand_invalid_count");
  }

  if(count == 0) {
    ERL_NIF_TERM empty_term;
    (void)enif_make_new_binary(env, 0, &empty_term);
    return make_result_ok(env, empty_term);
  }

  if(count > std::numeric_limits<size_t>::max() / sizeof(float)) {
    return make_result_error(env, "rand_count_too_large");
  }

  const size_t total_bytes = static_cast<size_t>(count) * sizeof(float);
  ERL_NIF_TERM out_term;
  unsigned char* out = enif_make_new_binary(env, total_bytes, &out_term);
  if(!out) {
    return make_result_error(env, "rand_alloc_failed");
  }

  float* out_f = reinterpret_cast<float*>(out);
  for(size_t i = 0; i < static_cast<size_t>(count); ++i) {
    out_f[i] = static_cast<float>(normal(rng));
  }

  return make_result_ok(env, out_term);
}
