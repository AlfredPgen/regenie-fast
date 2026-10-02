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

#ifndef BGEN8_PARSE_H
#define BGEN8_PARSE_H

#include <cstddef>
#include <cstdint>

// running sums and counts over the samples of one variant
struct bgen8_parse_sums {
  double total = 0, mac = 0, info_num = 0;
  uint32_t ns1 = 0, n_aa = 0, n_rr = 0;
  uint32_t n_missing = 0, n_out = 0; // analyzed samples with missing dosage (written -3) / samples not in the analysis
  uint32_t n_zero = 0, n_two = 0; // analyzed samples with dosage exactly 0 / 2
  uint32_t n_hm = 0; // analyzed samples with missing values in some trait (recorded for bgen8_trait_counts)
};

// has_missing == nullptr: no analyzed sample has missing values in some trait (single trait or strict mode)
// zero_out: samples not in the analysis are written 0 (else their dosage, or -3 if missing, as the slow path)
void bgen8_parse_fast(const unsigned char* probs, const unsigned char* ploidy, std::size_t nindivs,
    const bool* ind_ignore, const bool* in_analysis, const bool* has_missing, bool ref_first, bool count_hom,
    bool zero_out, double* geno, bgen8_parse_sums& sums, uint32_t* hm_index, double* hm_info);

// per-trait counts of the samples recorded by bgen8_parse_fast (as update_trait_counts in Geno.cpp)
void bgen8_trait_counts(const uint32_t* hm_index, const double* hm_info, std::size_t n_hm, const double* geno,
    const bool* mask, std::size_t mask_stride, int n_pheno, double* af, double* mac, double* info, int* ns);

// sums for the closed-form score tests (cf_variant in Step2_Models.cpp), in sample order
// quantitative traits: ss = sum_i c_i^2 and q[k] = sum_i mask_k[i] c_i^2, with c_i = g_i - mu e_i (e, mask_k: 0/1)
void cf_sumsq_qt(const double* g, const bool* e, double mu, std::size_t n, const bool* mask, std::size_t mask_stride, int nq, double& ss, double* q);
// binary traits: q[k] = sum_i (gam_k[i] (g_i - mu[k]))^2, with gam_k = gam + col[k] * gam_stride
void cf_sumsq_bt(const double* g, std::size_t n, const double* gam, std::size_t gam_stride, const int* col, const double* mu, int nq, double* q);

#endif
