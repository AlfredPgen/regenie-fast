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

// Fast parser for the 8-bit probabilities of one BGEN variant (common case of parseSnpfromBGEN).
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

void bgen8_parse_fast(const unsigned char* probs, const unsigned char* ploidy, std::size_t nindivs,
    const bool* ind_ignore, const bool* in_analysis, const bool* has_missing, bool ref_first, bool count_hom,
    double* geno, bgen8_parse_sums& sums, bgen8_trait_counts_fn trait_counts, void* ctx){

  double const inv255 = 1.0 / 255.0;
  double total = 0, mac = 0, info_num = 0;
  uint32_t ns1 = 0, n_aa = 0, n_rr = 0, n_missing = 0, n_out = 0;
  std::size_t index = 0;

  for(std::size_t i = 0; i < nindivs; i++, probs += 2) {

    // skip samples that were ignored from the analysis
    if( ind_ignore[i] ) continue;

    if( ploidy[i] & 0x80 ) { // missing
      geno[index++] = -3;
      n_missing++;
      continue;
    }

    double prob0 = double(probs[0]) * inv255;
    double prob1 = double(probs[1]) * inv255;
    double prob_a = ref_first ? std::max( 1 - (prob0 + prob1), 0.0) : prob0;
    double gval = (prob_a + prob_a) + prob1;
    geno[index] = gval;

    if( in_analysis[index] ){
      double ival = (4 * prob_a + prob1) - gval * gval;
      total += gval;
      mac += gval;
      info_num += ival;
      ns1++;

      // counts by trait
      if( has_missing[index] ) trait_counts(ctx, (int) index, gval, ival);

      if( count_hom ){
        if(gval >= 1.5) n_aa++;
        else if(gval < 0.5) n_rr++;
      }
    } else n_out++;

    index++;
  }

  sums.total = total; sums.mac = mac; sums.info_num = info_num;
  sums.ns1 = ns1; sums.n_aa = n_aa; sums.n_rr = n_rr; sums.n_missing = n_missing; sums.n_out = n_out;
}
