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
  uint32_t ns1 = 0, n_aa = 0, n_rr = 0, n_missing = 0, n_out = 0; // n_out: samples not in the analysis
};

// called (in sample order) for analyzed samples with missing values in some trait
typedef void (*bgen8_trait_counts_fn)(void* ctx, int index, double geno, double ival);

void bgen8_parse_fast(const unsigned char* probs, const unsigned char* ploidy, std::size_t nindivs,
    const bool* ind_ignore, const bool* in_analysis, const bool* has_missing, bool ref_first, bool count_hom,
    double* geno, bgen8_parse_sums& sums, bgen8_trait_counts_fn trait_counts, void* ctx);

#endif
