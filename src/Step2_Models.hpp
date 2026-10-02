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

#ifndef TEST_MODELS_H
#define TEST_MODELS_H

#define MAX_EXP_LIM 708

struct f_ests {

  Eigen::MatrixXd cov_blup_offset;
  Eigen::MatrixXd beta_null_firth;
  std::vector<std::shared_ptr<Files>> firth_est_files;
  double deviance_logistic;
  double bhat_firth, se_b_firth;
  
};

struct spa_data {

  Eigen::ArrayXd Gmod;
  double val_a, val_b, val_c, val_d;
  bool pos_score, fastSPA;

};

// Closed-form score statistics for dense variants (quantitative and binary traits).
// The score test of variant g only needs a few inner products of g, so instead of residualizing every
// genotype vector against the covariates (several passes over all samples per variant), these are computed
// for a whole block of variants with one matrix product S = W^T G. With an orthonormal covariate basis X and
// residual r = g - X X^T g (exact identities; c = g - mu e with e in span(X) keeps the sums well conditioned):
//   yres^T r          = yres^T c - (yres^T X) b,                       b = X^T c
//   sum_i m_i r_i^2   = sum_i m_i c_i^2 - 2 b^T (X_m^T c) + b^T (X_m^T X_m) b,   X_m = diag(m) X
// For binary traits the same holds with g, X and yres replaced by Gamma^1/2 g, X_Gamma and the score residuals.
struct cf_block {
  bool active = false;
  int n_pheno = 0, trait_mode = 0;
  Eigen::MatrixXd W, S; // W: N x K known vectors; S = W^T G (K x block size)
  // quantitative traits; W = [e | X | X_p of the traits in q_mask | yres] (yres from row y_row of S)
  int ncov = 0, y_row = 0;
  bool center = false;
  double ete = 0;
  Eigen::VectorXd e, Xte, Yte;
  ArrayXb e_ind; // e as 0/1
  Eigen::MatrixXd XtX, YtX;
  // traits masked as the analysis have X_p = X and the sums of all samples (q_col = -1); the others have their
  // mask in column k = q_col[p] of q_mask, and X_p^T g in rows 1 + C + k C of S
  std::vector<int> q_col;
  MatrixXb q_mask;
  std::vector<Eigen::VectorXd> Xpte;
  std::vector<Eigen::MatrixXd> XptXp;
  // binary traits, per trait p; W = [gamma_p^2 | X_Gamma_p o gamma_p | gamma_p o yres_p] for each p in traits
  std::vector<int> col, ncov_p, traits;
  std::vector<bool> center_p;
  std::vector<double> g2_sum, gy;
  std::vector<Eigen::VectorXd> Xwg, Xwy;
  std::vector<Eigen::MatrixXd> XwtXw;
};
bool cf_supported(struct param const&);
void cf_prepare(cf_block&,const Eigen::Ref<const Eigen::MatrixXd>&,const Eigen::Ref<const ArrayXb>&,struct param const&,struct phenodt const&,struct ests const&);
void cf_variant(cf_block const&,int const&,const Eigen::Ref<const Eigen::ArrayXd>&,variant_block*,struct data_thread*,struct param const&,struct ests const&);

void blup_read_chr(bool const&,int const&,struct ests&,struct in_files&,struct filter const&,struct phenodt const&,struct param&,mstream&);

// score tests
/* // for all snps/traits
void compute_score(std::vector<uint64> const& indices, int const& chrom, std::string const& test_string, std::string const& model_type, const Eigen::Ref<const Eigen::MatrixXd>& yres, const Eigen::Ref<const Eigen::RowVectorXd>& p_sd_yres, struct param const& params, struct phenodt& pheno_data, struct geno_block& gblock, std::vector<variant_block>& all_snps_info, std::vector<snp> const& snpinfo, struct ests const& m_ests, struct f_ests& fest, struct in_files const& files, mstream& sout);
void compute_score_qt(std::vector<uint64> const& indices, int const& chrom, std::string const& test_string, std::string const& model_type, const Eigen::Ref<const Eigen::MatrixXd>& yres, const Eigen::Ref<const Eigen::RowVectorXd>& p_sd_yres, struct param const& params, struct phenodt& pheno_data, struct geno_block& gblock, std::vector<variant_block>& all_snps_info, std::vector<snp> const& snpinfo, struct in_files const& files);
*/

void compute_score(int const&,int const&,int const&,int const&,std::string const&,std::string const&,const Eigen::Ref<const Eigen::MatrixXd>&,const Eigen::Ref<const Eigen::RowVectorXd>&,struct param const&,struct phenodt&,struct geno_block&,variant_block*,std::vector<snp> const&,struct ests const&,struct f_ests&,struct in_files&,mstream&);
void compute_score_qt(int const&,int const&,int const&,std::string const&,std::string const&,const Eigen::Ref<const Eigen::MatrixXd>&,const Eigen::Ref<const Eigen::RowVectorXd>&,struct param const&,struct phenodt&,struct geno_block&,variant_block*,std::vector<snp> const&,struct in_files&,mstream&);
void compute_score_qt_mcc(int const&,int const&,int const&,std::string const&,std::string const&,const Eigen::Ref<const Eigen::MatrixXd>&,const Eigen::Ref<const Eigen::RowVectorXd>&,struct param const&,struct phenodt&,struct geno_block&,variant_block*,std::vector<snp> const&,struct in_files&,mstream&);
void compute_score_bt(int const&,int const&,int const&,int const&,std::string const&,std::string const&,const Eigen::Ref<const Eigen::MatrixXd>&,struct param const&,struct phenodt&,struct geno_block&,variant_block*,std::vector<snp> const&,struct ests const&,struct f_ests&,struct in_files&,mstream&);
void compute_score_ct(int const&,int const&,int const&,int const&,std::string const&,std::string const&,const Eigen::Ref<const Eigen::MatrixXd>&,struct param const&,struct phenodt&,struct geno_block&,variant_block*,std::vector<snp> const&,struct ests const&,struct f_ests&,struct in_files&,mstream&);
void compute_score_cox(int const&, int const&, int const&, int const&, std::string const&, std::string const&, struct param const&, struct phenodt&, struct geno_block&, variant_block*, std::vector<snp> const&, struct ests const&, struct f_ests&, struct in_files&, mstream&);

void check_pval_snp(variant_block*,data_thread*,int const&,int const&,int const&,struct phenodt&,struct geno_block&,struct ests const&,struct f_ests&,struct param const&,mstream&);
void get_sumstats(bool const&,int const&,data_thread*);
void run_firth_correction_snp(int const&,int const&,int const&,struct geno_block&,variant_block*,data_thread*,struct phenodt&,struct ests const&,struct f_ests&,struct param const&,mstream&);

// firth
bool fit_approx_firth_null(int const&,int const&,struct phenodt const*,struct ests const*,Eigen::Ref<Eigen::ArrayXd>,struct param*, bool const& save_se = false);
void fit_null_firth(bool const&,int const&,struct f_ests*,struct phenodt*,struct ests const*,struct in_files*,struct param*,mstream&);
void fit_firth_logistic_snp(int const&,int const&,int const&,bool const&,struct param const*,struct phenodt*,struct ests const*,struct f_ests const*,const Eigen::Ref<const Eigen::MatrixXd>&,variant_block*,data_thread*,mstream&);
void fit_firth_logistic_snp_fast(int const&,int const&,int const&,bool const&,struct param const*,struct phenodt*,struct ests const*,struct f_ests const*,const Eigen::Ref<const Eigen::VectorXd>&,variant_block*,data_thread*,mstream&);
bool fit_firth(int const&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::MatrixXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&,Eigen::ArrayXd&,Eigen::ArrayXd&,Eigen::ArrayXd&,Eigen::ArrayXd&,int const&,double&,bool const&,double&,int const&,int const&,double const&,struct param const*,bool const& check_score_inc = true);
bool fit_firth_nr(double&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::MatrixXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&,Eigen::ArrayXd&,Eigen::ArrayXd&,Eigen::ArrayXd&,Eigen::ArrayXd&,int const&,double&,bool const&,double&,int const&,int const&,double const&,struct param const*,bool const& check_score_inc = true);
bool fit_firth_pseudo(double&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::MatrixXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&,Eigen::ArrayXd&,Eigen::ArrayXd&,Eigen::ArrayXd&,Eigen::ArrayXd&,int const&,double&,bool const&,double&,int const&,int const&,double const&,struct param const*, bool const& apply_early_checks = true);
uint fit_firth_pseudo(double const&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::VectorXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&,const Eigen::Ref<const Eigen::ArrayXi>&,double&,double&,double&,int const&,int const&,double const&,struct param const*);
bool fit_firth(double const&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::VectorXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&,const Eigen::Ref<const Eigen::ArrayXi>&,double&,double&,double&,int const&,int const&,double const&,struct param const*);
bool fit_firth_adam(int const&,double&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::MatrixXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&,Eigen::ArrayXd&,Eigen::ArrayXd&,Eigen::ArrayXd&,Eigen::ArrayXd&,int const&,double&,bool const&,double&,struct param const*);
std::string get_firth_est_allChr(struct in_files&,struct filter const& ,struct ests&,struct f_ests&,struct phenodt&,struct param&,mstream&);
std::string print_null_firth_info(struct in_files const&,struct f_ests&,struct param const&);
void check_beta_start_firth(struct in_files&,struct param const&,mstream&);
void get_beta_start_firth(const int&,struct f_ests*,struct in_files*,struct param const*,mstream&);
void get_beta_start_firth(struct f_ests*,struct ests const*);
void fit_null_firth_cox(bool const&, int const&, struct f_ests*, struct phenodt*, struct ests const*, struct in_files*, struct param*, mstream&);
void fit_firth_cox_snp(int const&, int const&, int const&, struct param const*, struct phenodt*, struct ests const*, struct f_ests const*, const Eigen::Ref<const Eigen::MatrixXd>&, variant_block*, data_thread*, mstream&);
void fit_firth_cox_snp_fast(int const&, int const&, int const&, struct param const*, struct phenodt*, struct ests const*, struct f_ests const*, const Eigen::Ref<const Eigen::VectorXd>&, variant_block*, data_thread*, mstream&);


// spa (multithreading in openmp)
void run_SPA_test(bool&,int const&,data_thread*,const Eigen::Ref<const ArrayXb>&,struct ests const&,struct param const&);
void run_SPA_test_snp(double&,double&,const double&,const double&,bool const&,SpVec const&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&,bool&,const double&,const double&,const double&,const double&);
double solve_K1_snp(const double&,const double&,SpVec const&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,struct spa_data&,const Eigen::Ref<const ArrayXb>&,const double&,const int&,const double&);
double compute_K_snp(const double&,const double&,const double&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&);
double compute_K1_snp(const double&,const double&,const double&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&);
double compute_K2_snp(const double&,const double&,const double&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&);
double compute_K_fast_snp(const double&,const double&,const double&,const double&,const double&,SpVec const&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&);
double compute_K1_fast_snp(const double&,const double&,const double&,const double&,const double&,SpVec const&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&);
double compute_K2_fast_snp(const double&,const double&,const double&,const double&,const double&,SpVec const&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const ArrayXb>&);
void get_SPA_pvalue_snp(const double&,const double&,double&,bool&,const double&,SpVec const&,const Eigen::Ref<const Eigen::ArrayXd>&,const Eigen::Ref<const Eigen::ArrayXd>&,struct spa_data&,const Eigen::Ref<const ArrayXb>&); 


// printing sum stats
std::string print_header_output(struct param const*);
std::string print_header_output_all(struct param const*);
std::string print_header_output_all_multitrait(struct param const*);
std::string print_header_output_all_multiphen(struct param const*);
std::string print_header_output_single(struct param const*);
std::string print_header_output_htp();
std::string print_sum_stats_head(const int&,std::vector<snp> const&);
std::string print_sum_stats_head_htp(const int&,const std::string&,const std::string&,std::vector<snp> const&,struct param const*);
std::string print_sum_stats(const double&,const double&,const double&,const int&,const int&,const double&,const int&,const int&,const int&,const std::string&,const double&,const double&,const double&,const double&,const bool&,const int&,struct param const*,int const&);
std::string print_sum_stats_all(const double&,const double&,const double&,const int&,const int&,const double&,const int&,const int&,const int&,const std::string&,const double&,const double&,const double&,const double&,const bool&,const int&,struct param const*,int const&);
std::string print_na_sumstats(const int&,const int&,const std::string&,const std::string&,variant_block const*,struct param const&);
std::string print_sum_stats_single(const double&,const double&,const double&,const double&,const int&,const int&,const int&,const std::string&,const double&,const double&,const double&,const double&,const bool&,const int&,struct param const*);
std::string print_sum_stats_htp(const double&,const double&,const double&,const double&,const double&,const double&,const double&,const Eigen::Ref<const Eigen::MatrixXi>&,const int&,const bool&,const int&,struct param const*, const double& score = -999, const double& cal_factor = -1.0, const double& cal_factor_burden = -1.0, const double& skat_diag = -999);
std::string print_sum_stats_line(int const&,int const&,std::string const&,std::string const&,std::string const&,variant_block*,data_thread*,std::vector<snp> const&,struct in_files&,struct param const&);

std::string print_summary(Files*,std::string const&,std::vector<std::shared_ptr<Files>>&,std::vector< std::string >const&,int const&,struct tally const&,struct in_files const&,struct f_ests&,struct param const&);

#endif
