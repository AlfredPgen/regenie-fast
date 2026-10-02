/*

   This file is part of the regenie software package.

   Copyright (c) 2020-2024 Joelle Mbatchou, Andrey Ziyatdinov & Jonathan Marchini

   Permission is hereby granted, free of charge, to any person obtaining a copy
   of this software and associated documentation files (the "Software"), to deal
   in the Software without restriction, including without limitation the rights
   to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
   copies of the Software, and to permit persons to whom the Software is
   furnished to do so, subject to the following conditions:

   The above copyright notice and this permission notice shall be included in all
   copies or substantial portions of the Software.

   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
   IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
   FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
   AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
   LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
   OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
   SOFTWARE.

*/

// Fast parser for the 8-bit probabilities of one BGEN variant (common case of parseSnpfromBGEN), and the
// per-sample sums of the closed-form score tests (cf_variant in Step2_Models.cpp).
//
// This file is compiled WITHOUT -ffast-math and with -ffp-contract=off (see CMakeLists.txt): every
// operation below is a single IEEE-rounded instruction in the order written, and the running sums are
// never reordered. The sequence is the one parseSnpfromBGEN performs per sample:
//   prob = byte * (1/255)              [-ffast-math turns the division by 255 into this multiply]
//   prob2 = max(1 - (prob0 + prob1), 0)
//   dosage = 2 * prob_a + prob1        [2 * x is exact]
//   info term = (4 * prob_a + prob1) - dosage * dosage   [4 * x is exact]
// where prob_a = prob0 (default) or prob2 (--ref-first), so the results are bit-identical.

#include <algorithm>
#include "bgen8_parse.hpp"

namespace {

// dosage of one sample (prob_a and prob1 are kept for the info term)
template<bool REF_FIRST>
inline double dosage(const unsigned char* probs, double inv255, double& prob_a, double& prob1){
  double prob0 = double(probs[0]) * inv255;
  prob1 = double(probs[1]) * inv255;
  prob_a = REF_FIRST ? std::max( 1 - (prob0 + prob1), 0.0) : prob0;
  return (prob_a + prob_a) + prob1;
}

template<bool REF_FIRST, bool COUNT_HOM, bool TRACK>
void parse_loop(const unsigned char* probs, const unsigned char* ploidy, std::size_t nindivs,
    const bool* ind_ignore, const bool* in_analysis, const bool* has_missing, bool zero_out,
    double* geno, bgen8_parse_sums& sums, uint32_t* hm_index, double* hm_info){

  double const inv255 = 1.0 / 255.0;
  double total = 0, info_num = 0, prob_a, prob1;
  uint32_t ns1 = 0, n_aa = 0, n_rr = 0, n_missing = 0, n_out = 0, n_zero = 0, n_two = 0, n_hm = 0;
  std::size_t index = 0;

  for(std::size_t i = 0; i < nindivs; i++, probs += 2) {

    // skip samples that were ignored from the analysis
    if( ind_ignore[i] ) continue;

    // samples not in the analysis: their final value 0 (as mean imputation sets them), or else the
    // dosage (-3 if missing) as written by the slow path
    if( !in_analysis[index] ) {
      geno[index++] = zero_out ? 0 : (ploidy[i] & 0x80) ? -3 : dosage<REF_FIRST>(probs, inv255, prob_a, prob1);
      n_out++;
      continue;
    }

    if( ploidy[i] & 0x80 ) { // missing
      geno[index++] = -3;
      n_missing++;
      continue;
    }

    double gval = dosage<REF_FIRST>(probs, inv255, prob_a, prob1);
    double ival = (4 * prob_a + prob1) - gval * gval;
    geno[index] = gval;
    total += gval;
    info_num += ival;
    ns1++;
    n_zero += (gval == 0.0);
    n_two += (gval == 2.0);

    // counts by trait (see bgen8_trait_counts)
    if( TRACK && has_missing[index] ) {
      hm_index[n_hm] = (uint32_t) index;
      hm_info[n_hm] = ival;
      n_hm++;
    }

    if( COUNT_HOM ){ // the two cases are exclusive
      n_aa += (gval >= 1.5);
      n_rr += (gval < 0.5);
    }

    index++;
  }

  // mac adds the same values as total in the same order
  sums.total = total; sums.mac = total; sums.info_num = info_num;
  sums.ns1 = ns1; sums.n_aa = n_aa; sums.n_rr = n_rr; sums.n_missing = n_missing; sums.n_out = n_out;
  sums.n_zero = n_zero; sums.n_two = n_two; sums.n_hm = n_hm;
}

typedef void (*parse_loop_fn)(const unsigned char*, const unsigned char*, std::size_t, const bool*, const bool*, const bool*, bool, double*, bgen8_parse_sums&, uint32_t*, double*);

// QT: ss and the masked sums of NQ traits, one accumulator each
template<int NQ, bool SS>
void sumsq_qt(const double* g, const bool* e, double mu, std::size_t n, const bool* mask, std::size_t mask_stride, double& ss, double* q){

  const bool* m[NQ + 1];
  double s = 0, a[NQ + 1] = {};
  for(int k = 0; k < NQ; k++) m[k] = mask + k * mask_stride;

  for(std::size_t i = 0; i < n; i++){
    double const ci = g[i] - mu * double(e[i]);
    double const c2 = ci * ci;
    if(SS) s += c2;
    for(int k = 0; k < NQ; k++) a[k] += double(m[k][i]) * c2;
  }

  if(SS) ss = s;
  for(int k = 0; k < NQ; k++) q[k] = a[k];
}

template<bool SS>
void sumsq_qt_n(int nq, const double* g, const bool* e, double mu, std::size_t n, const bool* mask, std::size_t mask_stride, double& ss, double* q){
  switch(nq){
    case 0: sumsq_qt<0, SS>(g, e, mu, n, mask, mask_stride, ss, q); break;
    case 1: sumsq_qt<1, SS>(g, e, mu, n, mask, mask_stride, ss, q); break;
    case 2: sumsq_qt<2, SS>(g, e, mu, n, mask, mask_stride, ss, q); break;
    case 3: sumsq_qt<3, SS>(g, e, mu, n, mask, mask_stride, ss, q); break;
    default: sumsq_qt<4, SS>(g, e, mu, n, mask, mask_stride, ss, q);
  }
}

// BT: NQ traits in one pass over the genotypes, one accumulator each
template<int NQ>
void sumsq_bt(const double* g, std::size_t n, const double* const* gam, const double* mu, double* q){

  const double* w[NQ];
  double m[NQ], a[NQ] = {};
  for(int k = 0; k < NQ; k++) { w[k] = gam[k]; m[k] = mu[k]; }

  for(std::size_t i = 0; i < n; i++){
    double const gi = g[i];
    for(int k = 0; k < NQ; k++){
      double const d = w[k][i] * (gi - m[k]);
      a[k] += d * d;
    }
  }

  for(int k = 0; k < NQ; k++) q[k] = a[k];
}

}

void bgen8_parse_fast(const unsigned char* probs, const unsigned char* ploidy, std::size_t nindivs,
    const bool* ind_ignore, const bool* in_analysis, const bool* has_missing, bool ref_first, bool count_hom,
    bool zero_out, double* geno, bgen8_parse_sums& sums, uint32_t* hm_index, double* hm_info){

  static parse_loop_fn const loops[8] = {
    parse_loop<false, false, false>, parse_loop<false, false, true>, parse_loop<false, true, false>, parse_loop<false, true, true>,
    parse_loop<true, false, false>, parse_loop<true, false, true>, parse_loop<true, true, false>, parse_loop<true, true, true> };

  loops[4 * ref_first + 2 * count_hom + (has_missing != nullptr)](probs, ploidy, nindivs, ind_ignore, in_analysis, has_missing, zero_out, geno, sums, hm_index, hm_info);
}

// For an analyzed sample masked in trait p, update_trait_counts (Geno.cpp) subtracts its dosage from af(p) and
// mac(p), its info term from info(p) and 1 from ns(p); for the other traits it subtracts +0, which changes nothing
// (these sums start at +0 and so are never -0). Per trait, the subtractions are applied in sample order as there.
void bgen8_trait_counts(const uint32_t* hm_index, const double* hm_info, std::size_t n_hm, const double* geno,
    const bool* mask, std::size_t mask_stride, int n_pheno, double* af, double* mac, double* info, int* ns){

  for(int p = 0; p < n_pheno; p++){
    const bool* m = mask + p * mask_stride;
    double a = af[p], b = mac[p], c = info[p];
    int n = ns[p];
    for(std::size_t k = 0; k < n_hm; k++){
      uint32_t const index = hm_index[k];
      if( m[index] ) continue;
      a -= geno[index];
      b -= geno[index];
      c -= hm_info[k];
      n--;
    }
    af[p] = a; mac[p] = b; info[p] = c; ns[p] = n;
  }
}

// Same operations, in the same order, as the per-sample loops of cf_variant: c_i = g_i - mu * e_i,
// ss += c_i * c_i and q_k += mask_k[i] * (c_i * c_i) (QT); d = gam_k[i] * (g_i - mu_k) and q_k += d * d (BT).
// Traits are taken 4 at a time, each sum in its own accumulator.
void cf_sumsq_qt(const double* g, const bool* e, double mu, std::size_t n, const bool* mask, std::size_t mask_stride, int nq, double& ss, double* q){

  sumsq_qt_n<true>(std::min(nq, 4), g, e, mu, n, mask, mask_stride, ss, q);
  for(int k = 4; k < nq; k += 4)
    sumsq_qt_n<false>(std::min(nq - k, 4), g, e, mu, n, mask + k * mask_stride, mask_stride, ss, q + k);
}

void cf_sumsq_bt(const double* g, std::size_t n, const double* gam, std::size_t gam_stride, const int* col, const double* mu, int nq, double* q){

  for(int k0 = 0; k0 < nq; k0 += 4){
    int const nk = std::min(nq - k0, 4);
    const double* w[4];
    for(int k = 0; k < nk; k++) w[k] = gam + col[k0 + k] * gam_stride;
    switch(nk){
      case 1: sumsq_bt<1>(g, n, w, mu + k0, q + k0); break;
      case 2: sumsq_bt<2>(g, n, w, mu + k0, q + k0); break;
      case 3: sumsq_bt<3>(g, n, w, mu + k0, q + k0); break;
      default: sumsq_bt<4>(g, n, w, mu + k0, q + k0);
    }
  }
}
