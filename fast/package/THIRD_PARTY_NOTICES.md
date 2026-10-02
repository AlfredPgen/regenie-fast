# Third-party notices

This file covers the release archive `regenie-fast-linux-x86_64.zip` of regenie-fast `v4.1.3-fast1`
(https://github.com/AlfredPgen/regenie-fast). It lists everything the archive redistributes, the licence of each
part, and the notices those licences require.

- `licenses/` holds the full licence texts, including the Ubuntu copyright file of every bundled library.
- `libs.csv` lists every file in `lib/` with its Ubuntu package, version, licence and SHA-256 checksum.
- `sources.csv` lists the exact source files of those Ubuntu packages.

regenie is written by Joelle Mbatchou, Andrey Ziyatdinov, Jonathan Marchini and contributors
(https://github.com/rgcgithub/regenie) and is distributed under the MIT licence. regenie-fast is an independent
build of regenie v4.1.3 with performance changes. It is not an official regenie release. If you use it, please cite
regenie:

> Mbatchou, J., Barnard, L., Backman, J. et al. Computationally efficient whole-genome regression for quantitative
> and binary traits. Nat Genet 53, 1097–1103 (2021). https://doi.org/10.1038/s41588-021-00870-7

## 1. Contents of the archive

| Path | What it is | Licence |
|---|---|---|
| `bin/regenie-4.1.3-fast` | regenie 4.1.3 with the changes in this repository. Building tag `v4.1.3-fast1` with the recipe in `fast/build/` gives this file bit for bit (SHA-256 `61cbf8994d43d547929718e6f33b3d63255ad1bda3314e7eba4f06d74e9fa6c5`; `fast/results/rebuild_v4.1.3-fast1.log` in the repository) | MIT, plus the components in section 2 |
| `bin/regenie-4.1.3-official` | The official regenie v4.1.3 Linux binary `regenie_v4.1.3.gz_x86_64_Linux_mkl` from https://github.com/rgcgithub/regenie/releases/tag/v4.1.3, unmodified | MIT, plus the components in section 2 |
| `lib/` (40 files) | Unmodified shared libraries and dynamic loader from Ubuntu 22.04 packages. The launchers run both programs with them. | See section 3 |
| `test/` | Example data from regenie's `example/` folder, unmodified | MIT (regenie) |
| `regenie-fast`, `regenie-official`, `selftest.sh`, `compare_with_official.sh`, `README.md`, `regenie-4.1.3-fast.patch` | Launchers, test scripts, documentation and the source patch of this repository | MIT, the same licence as regenie |
| `LICENSE`, `THIRD_PARTY_NOTICES.md`, `libs.csv`, `sources.csv`, `licenses/` | regenie's MIT licence, this file and the licence texts | |

`bin/regenie-4.1.3-official` has SHA-256
`d8dc4118a895cd179e1fdef53d4caee8536a45aeb5aab69ac8c78e2e8e3c0055`, the same as the file in the official release
zip.

## 2. Code compiled into the two programs

Both programs are statically linked with the code below. Libraries loaded at run time from `lib/` are listed in
section 3. For `regenie-4.1.3-fast` the versions come from its build recipe. For `regenie-4.1.3-official` they were
read from version strings and symbols in the binary; "included" means the code is present but its version is not
recorded.

| Component | Licence | In `regenie-4.1.3-fast` | In `regenie-4.1.3-official` | Licence text in `licenses/` |
|---|---|---|---|---|
| regenie | MIT | 4.1.3 with this repository's changes | 4.1.3 | `regenie.txt` |
| Intel oneAPI Math Kernel Library (oneMKL) | Intel Simplified Software License (October 2022) | 2024.2.0 (build 20240605) | 2024.2.0 (build 20240605) | `intel-onemkl.txt`, `intel-onemkl-third-party-programs.txt`, `intel-onemkl-third-party-programs-safestring.txt` |
| BGEN library (Gavin Band) | BSL-1.0 | v1.1.7 | included | `bgen.txt` |
| Zstandard, bundled with BGEN | BSD-3-Clause, with patent grant | 1.1.0 | included | `zstd-1.1.0.txt` |
| SQLite, bundled with BGEN | Public domain | 3.9.2 | 3.9.2 | `sqlite.txt` |
| Boost system, thread, filesystem, date_time, timer and chrono, bundled with BGEN | BSL-1.0 | 1.55.0 | included | `boost.txt` |
| Boost.Iostreams | BSL-1.0 | 1.74.0 (Ubuntu 1.74.0-14ubuntu3) | included | `boost.txt` |
| HTSlib, with htscodecs | MIT/Expat; CRAM code and htscodecs BSD-3-Clause; some parts public domain | 1.18 | 1.12 | `htslib.txt` |
| libdeflate | MIT | 1.26 | not included | `libdeflate.txt` |
| zlib | Zlib | 1.2.11 (Ubuntu 1:1.2.11.dfsg-2ubuntu9.2) | 1.2.11 | `ubuntu/zlib.txt` |
| Eigen (header-only) | MPL-2.0; a few files BSD-3-Clause or Apache-2.0 | 3.4.0 | 3.4.0 | `eigen.txt`, `MPL-2.0.txt`, `Apache-2.0.txt` |
| pgenlib (PLINK 2.0 `.pgen` reader), with SIMDe headers | LGPL-3.0-or-later; SIMDe MIT, partly CC0-1.0 | as in regenie 4.1.3 | as in regenie 4.1.3 | `pgenlib.txt`, `LGPL-3.0.txt`, `GPL-3.0.txt` |
| cxxopts (header-only) | MIT | as in regenie 4.1.3 | as in regenie 4.1.3 | `cxxopts.txt` |
| LBFGSpp (header-only) | MIT | as in regenie 4.1.3 | as in regenie 4.1.3 | `LBFGSpp.txt` |
| MVTDST by Alan Genz, via the R package mvtnorm | Not stated in the source, see section 5.3 | as in regenie 4.1.3 | as in regenie 4.1.3 | `mvtnorm.txt` |
| qfc by Robert Davies | Not stated in the source, see section 5.3 | as in regenie 4.1.3 | as in regenie 4.1.3 | `qf.txt` |
| QUADPACK and D1MACH (netlib) | Not stated in the source, see section 5.3 | as in regenie 4.1.3 | as in regenie 4.1.3 | `quadpack.txt` |
| GNU C++ library (libstdc++) and libgcc | GPL-3.0-or-later WITH GCC-exception-3.1 | GCC 9.5.0 (Ubuntu gcc-9 9.5.0-1ubuntu1~22.04.1) | included | `GCC-exception-3.1.txt`, `GPL-3.0.txt`, `ubuntu/gcc-9.txt` |
| GNU C Library start-up files and `libc_nonshared.a` | LGPL-2.1-or-later, with an exception that permits linking them into any program | 2.35 | 2.35 | `ubuntu/glibc.txt` |
| OpenSSL `libcrypto` | Apache-2.0 | not included (uses `lib/libcrypto.so.3`) | OpenSSL 3 | `Apache-2.0.txt`, `ubuntu/openssl.txt` |
| bzip2 (`libbz2`) | bzip2-1.0.6 (BSD-style) | not included (uses `lib/libbz2.so.1.0`) | 1.0.8 | `ubuntu/bzip2.txt` |
| XZ Utils (`liblzma`) | Public domain | not included (uses `lib/liblzma.so.5`) | 5.2.5 | `ubuntu/xz-utils.txt` |
| GNU Fortran runtime (`libgfortran`) | GPL-3.0-or-later WITH GCC-exception-3.1 | not included (uses `lib/libgfortran.so.5`) | GCC 9 | `GCC-exception-3.1.txt`, `ubuntu/gcc-9.txt` |
| `libquadmath` (GCC) | LGPL-2.1-or-later | not included (uses `lib/libquadmath.so.0`) | GCC 9 | `LGPL-2.1.txt`, `ubuntu/gcc-9.txt` |

Both programs use oneMKL's GNU OpenMP threading layer. Neither contains Intel's OpenMP runtime, oneTBB, MPI or SYCL
components (no symbols from them are present).

## 3. Shared libraries in `lib/`

All 40 files in `lib/` are unmodified copies of files installed by the Ubuntu 22.04 (jammy, amd64) packages below.
Each file matches, by SHA-256, the file its package installs in the Ubuntu 22.04.5 image used to build
`regenie-4.1.3-fast` (packages identified with `dpkg -S` and `dpkg-query`). Both launchers load these files instead
of the system's own libraries.

| Files in `lib/` | Ubuntu package | Version | Licence | Copyright file |
|---|---|---|---|---|
| `libbrotlicommon.so.1`, `libbrotlidec.so.1` | libbrotli1 | 1.0.9-2build6 | MIT | `licenses/ubuntu/brotli.txt` |
| `libbz2.so.1.0` | libbz2-1.0 | 1.0.8-5ubuntu0.1 | bzip2-1.0.6 (BSD-style) | `licenses/ubuntu/bzip2.txt` |
| `ld-linux-x86-64.so.2`, `libc.so.6`, `libm.so.6`, `libmvec.so.1`, `libresolv.so.2` | libc6 | 2.35-0ubuntu3.15 | LGPL-2.1-or-later (some files under other free licences) | `licenses/ubuntu/glibc.txt` |
| `libcom_err.so.2` | libcom-err2 | 1.46.5-2ubuntu1.2 | MIT-style (MIT SIPB) | `licenses/ubuntu/e2fsprogs.txt` |
| `libcrypto.so.3`, `libssl.so.3` | libssl3 | 3.0.2-0ubuntu1.30 | Apache-2.0 | `licenses/ubuntu/openssl.txt` |
| `libcurl.so.4` | libcurl4 | 7.81.0-1ubuntu1.29 | curl (MIT-style) | `licenses/ubuntu/curl.txt` |
| `libffi.so.8` | libffi8 | 3.4.2-4 | MIT | `licenses/ubuntu/libffi.txt` |
| `libgcc_s.so.1` | libgcc-s1 | 12.3.0-1ubuntu1~22.04.3 | GPL-3.0-or-later WITH GCC-exception-3.1 | `licenses/ubuntu/gcc-12.txt` |
| `libgfortran.so.5` | libgfortran5 | 12.3.0-1ubuntu1~22.04.3 | GPL-3.0-or-later WITH GCC-exception-3.1 | `licenses/ubuntu/gcc-12.txt` |
| `libgmp.so.10` | libgmp10 | 2:6.2.1+dfsg-3ubuntu1 | LGPL-3.0-or-later OR GPL-2.0-or-later | `licenses/ubuntu/gmp.txt` |
| `libgnutls.so.30` | libgnutls30 | 3.7.3-4ubuntu1.9 | LGPL-2.1-or-later | `licenses/ubuntu/gnutls28.txt` |
| `libgomp.so.1` | libgomp1 | 12.3.0-1ubuntu1~22.04.3 | GPL-3.0-or-later WITH GCC-exception-3.1 | `licenses/ubuntu/gcc-12.txt` |
| `libgssapi_krb5.so.2` | libgssapi-krb5-2 | 1.19.2-2ubuntu0.10 | MIT-style (MIT Kerberos) | `licenses/ubuntu/krb5.txt` |
| `libhogweed.so.6` | libhogweed6 | 3.7.3-1build2 | LGPL-3.0-or-later OR GPL-2.0-or-later | `licenses/ubuntu/nettle.txt` |
| `libidn2.so.0` | libidn2-0 | 2.3.2-2build1 | LGPL-3.0-or-later OR GPL-2.0-or-later | `licenses/ubuntu/libidn2.txt` |
| `libk5crypto.so.3` | libk5crypto3 | 1.19.2-2ubuntu0.10 | MIT-style (MIT Kerberos) | `licenses/ubuntu/krb5.txt` |
| `libkeyutils.so.1` | libkeyutils1 | 1.6.1-2ubuntu3 | LGPL-2.0-or-later | `licenses/ubuntu/keyutils.txt` |
| `libkrb5.so.3` | libkrb5-3 | 1.19.2-2ubuntu0.10 | MIT-style (MIT Kerberos) | `licenses/ubuntu/krb5.txt` |
| `libkrb5support.so.0` | libkrb5support0 | 1.19.2-2ubuntu0.10 | MIT-style (MIT Kerberos) | `licenses/ubuntu/krb5.txt` |
| `liblber-2.5.so.0`, `libldap-2.5.so.0` | libldap-2.5-0 | 2.5.20+dfsg-0ubuntu0.22.04.1 | OLDAP-2.8 | `licenses/ubuntu/openldap.txt` |
| `liblzma.so.5` | liblzma5 | 5.2.5-2ubuntu1.1 | Public domain | `licenses/ubuntu/xz-utils.txt` |
| `libnettle.so.8` | libnettle8 | 3.7.3-1build2 | LGPL-3.0-or-later OR GPL-2.0-or-later | `licenses/ubuntu/nettle.txt` |
| `libnghttp2.so.14` | libnghttp2-14 | 1.43.0-1ubuntu0.4 | MIT | `licenses/ubuntu/nghttp2.txt` |
| `libp11-kit.so.0` | libp11-kit0 | 0.24.0-6ubuntu0.1 | BSD-3-Clause | `licenses/ubuntu/p11-kit.txt` |
| `libpsl.so.5` | libpsl5 | 0.21.0-1.2build2 | MIT | `licenses/ubuntu/libpsl.txt` |
| `libquadmath.so.0` | libquadmath0 | 12.3.0-1ubuntu1~22.04.3 | LGPL-2.1-or-later (some files LGPL-2.0-or-later) | `licenses/ubuntu/gcc-12.txt` |
| `librtmp.so.1` | librtmp1 | 2.4+20151223.gitfa8646d.1-2build4 | LGPL-2.1-or-later | `licenses/ubuntu/rtmpdump.txt` |
| `libsasl2.so.2` | libsasl2-2 | 2.1.27+dfsg2-3ubuntu1.2 | BSD-style with attribution clause (Carnegie Mellon) | `licenses/ubuntu/cyrus-sasl2.txt` |
| `libssh.so.4` | libssh-4 | 0.9.6-2ubuntu0.22.04.8 | LGPL-2.1-or-later | `licenses/ubuntu/libssh.txt` |
| `libtasn1.so.6` | libtasn1-6 | 4.18.0-4ubuntu0.2 | LGPL-2.1-or-later | `licenses/ubuntu/libtasn1-6.txt` |
| `libunistring.so.2` | libunistring2 | 1.0-1 | LGPL-3.0-or-later OR GPL-2.0-or-later | `licenses/ubuntu/libunistring.txt` |
| `libz.so.1` | zlib1g | 1:1.2.11.dfsg-2ubuntu9.2 | Zlib | `licenses/ubuntu/zlib.txt` |
| `libzstd.so.1` | libzstd1 | 1.4.8+dfsg-3build1 | BSD-3-Clause OR GPL-2.0-only | `licenses/ubuntu/libzstd.txt` |

## 4. Source code for the GPL- and LGPL-licensed parts

### 4.1 Libraries in `lib/`

The files below are licensed under the GNU GPL or LGPL. They are unmodified binaries from the Ubuntu 22.04 packages
named. Their complete corresponding source code is the Ubuntu source package of exactly the version shown. Each
Launchpad page links to the upstream source tarball, the Ubuntu changes (`.debian.tar.*`) and the `.dsc` file.
`sources.csv` lists the direct download URL of every one of those files.

| Files in `lib/` | Licence | Ubuntu source package | Source code |
|---|---|---|---|
| `ld-linux-x86-64.so.2`, `libc.so.6`, `libm.so.6`, `libmvec.so.1`, `libresolv.so.2` | LGPL-2.1-or-later | glibc 2.35-0ubuntu3.15 | https://launchpad.net/ubuntu/+source/glibc/2.35-0ubuntu3.15 |
| `libgcc_s.so.1`, `libgfortran.so.5`, `libgomp.so.1`, `libquadmath.so.0` | `libquadmath.so.0`: LGPL-2.1-or-later; the others: GPL-3.0-or-later WITH GCC-exception-3.1 | gcc-12 12.3.0-1ubuntu1~22.04.3 | https://launchpad.net/ubuntu/+source/gcc-12/12.3.0-1ubuntu1~22.04.3 |
| `libgmp.so.10` | LGPL-3.0-or-later OR GPL-2.0-or-later | gmp 2:6.2.1+dfsg-3ubuntu1 | https://launchpad.net/ubuntu/+source/gmp/2:6.2.1+dfsg-3ubuntu1 |
| `libgnutls.so.30` | LGPL-2.1-or-later | gnutls28 3.7.3-4ubuntu1.9 | https://launchpad.net/ubuntu/+source/gnutls28/3.7.3-4ubuntu1.9 |
| `libhogweed.so.6`, `libnettle.so.8` | LGPL-3.0-or-later OR GPL-2.0-or-later | nettle 3.7.3-1build2 | https://launchpad.net/ubuntu/+source/nettle/3.7.3-1build2 |
| `libidn2.so.0` | LGPL-3.0-or-later OR GPL-2.0-or-later | libidn2 2.3.2-2build1 | https://launchpad.net/ubuntu/+source/libidn2/2.3.2-2build1 |
| `libunistring.so.2` | LGPL-3.0-or-later OR GPL-2.0-or-later | libunistring 1.0-1 | https://launchpad.net/ubuntu/+source/libunistring/1.0-1 |
| `libtasn1.so.6` | LGPL-2.1-or-later | libtasn1-6 4.18.0-4ubuntu0.2 | https://launchpad.net/ubuntu/+source/libtasn1-6/4.18.0-4ubuntu0.2 |
| `libssh.so.4` | LGPL-2.1-or-later | libssh 0.9.6-2ubuntu0.22.04.8 | https://launchpad.net/ubuntu/+source/libssh/0.9.6-2ubuntu0.22.04.8 |
| `librtmp.so.1` | LGPL-2.1-or-later | rtmpdump 2.4+20151223.gitfa8646d.1-2build4 | https://launchpad.net/ubuntu/+source/rtmpdump/2.4+20151223.gitfa8646d.1-2build4 |
| `libkeyutils.so.1` | LGPL-2.0-or-later | keyutils 1.6.1-2ubuntu3 | https://launchpad.net/ubuntu/+source/keyutils/1.6.1-2ubuntu3 |

The Ubuntu source packages for the other libraries in `lib/` are listed in `libs.csv` and `sources.csv` in the same
way.

A copy of the source packages of all the GPL- and LGPL-licensed files above, and of gcc-9 (section 4.2), is attached
to the GitHub release `v4.1.3-fast1` (https://github.com/AlfredPgen/regenie-fast/releases/tag/v4.1.3-fast1) as
`regenie-fast-v4.1.3-fast1-gpl-sources.tar`, next to this archive, so that the source stays available from the same
place as the binaries even if the Launchpad links change.

### 4.2 LGPL code compiled into the programs

pgenlib (LGPL-3.0-or-later) is compiled into both programs. The source needed to rebuild either program with a
modified pgenlib is public:

- `regenie-4.1.3-fast`: the source is this repository at tag `v4.1.3-fast1`, with pgenlib in `external_libs/pgenlib`.
  The Docker recipe in `fast/build/` builds it. Its other inputs are public downloads: Intel oneMKL 2024.2.0 from
  Intel's apt repository, BGEN v1.1.7, HTSlib 1.18, libdeflate 1.26 and Ubuntu 22.04 packages.
- `regenie-4.1.3-official`: the source is regenie v4.1.3 at https://github.com/rgcgithub/regenie/tree/v4.1.3, with
  pgenlib in the same folder. Build instructions are in that repository (`README.md`, `Dockerfile_mkl`).

Both programs print regenie's copyright notice when they run, and that notice does not mention pgenlib or the LGPL.
This is inherited unchanged from regenie v4.1.3: regenie-fast does not change the program's output, including this
notice. The notice for pgenlib is therefore given here: pgenlib is part of PLINK 2.0, copyright (C) 2005-2024 Shaun
Purcell, Christopher Chang, and is licensed under the GNU Lesser General Public License, version 3 or (at your option)
any later version (`licenses/pgenlib.txt`, `licenses/LGPL-3.0.txt`, `licenses/GPL-3.0.txt`).

libquadmath (LGPL-2.1-or-later) is compiled into `regenie-4.1.3-official` only, by the regenie authors. The
instruction sequences of the 30 libquadmath functions in that binary match the static libquadmath of Ubuntu 22.04's
gcc-9 9.5.0-1ubuntu1~22.04.1, and those of its 251 libgfortran functions match the same package. Its source is
therefore the `libquadmath/` folder of that source package:
https://launchpad.net/ubuntu/+source/gcc-9/9.5.0-1ubuntu1~22.04.1

libstdc++ and libgcc (both programs) and libgfortran (`regenie-4.1.3-official` only) are compiled in under the GCC
Runtime Library Exception (`licenses/GCC-exception-3.1.txt`), which lets programs compiled with GCC be distributed
under terms of the distributor's choice. Their source is the same gcc-9 source package.

### 4.3 Replacing the bundled libraries

Both programs are dynamically linked against the libraries in `lib/`. The launchers start them with the bundled
loader and `--library-path lib`. You can therefore replace any file in `lib/` with a compatible build, for example
one rebuilt from modified source, without relinking either program.

## 5. Required notices

### 5.1 regenie

Copyright (c) 2020-2021 Joelle Mbatchou, Andrey Ziyatdinov & Jonathan Marchini. MIT licence; the full text, with
the BGEN notice that regenie's LICENSE includes, is in `licenses/regenie.txt`.

The changes of regenie-fast (https://github.com/AlfredPgen/regenie-fast) are Copyright (c) 2026 AlfredPgen and are
distributed under the same MIT licence.

### 5.2 Intel oneAPI Math Kernel Library

Both programs contain Intel oneMKL 2024.2.0, statically linked and unmodified. Its licence allows redistribution
in binary form without modification, provided that its copyright notice and terms are reproduced in the
documentation of the distribution. They follow in full. Intel does not endorse this build.

```
Intel Simplified Software License (Version October 2022)

Intel® oneAPI Math Kernel Library (oneMKL): Copyright (C) 1985 Intel Corporation

Use and Redistribution.  You may use and redistribute the software, which 
is provided in binary form only, (the “Software”), without modification, 
provided the following conditions are met:

* Redistributions must reproduce the above copyright notice and these terms 
  of use in the Software and in the documentation and/or other materials 
  provided with the distribution.
* Neither the name of Intel nor the names of its suppliers may be used to 
  endorse or promote products derived from this Software without specific 
  prior written permission.
* No reverse engineering, decompilation, or disassembly of the Software is 
  permitted, nor any modification or alteration of the Software or its 
  operation at any time, including during execution.

No other licenses.  Except as provided in the preceding section, Intel grants no 
licenses or other rights by implication, estoppel or otherwise to, patent, 
copyright, trademark, trade name, service mark or other intellectual property 
licenses or rights of Intel.

Third party software.  “Third Party Software” means the files (if any) listed in 
the “third-party-software.txt” or other similarly-named text file that may be 
included with the Software. Third Party Software, even if included with the 
distribution of the Software, may be governed by separate license terms, 
including without limitation, third party license terms, open source software 
notices and terms, and/or other Intel software license terms. These separate 
license terms solely govern Your use of the Third Party Software.

DISCLAIMER.  THIS SOFTWARE IS PROVIDED "AS IS" AND ANY EXPRESS OR IMPLIED 
WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES OF 
MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE, AND NON-INFRINGEMENT ARE 
DISCLAIMED. THIS SOFTWARE IS NOT INTENDED FOR USE IN SYSTEMS OR APPLICATIONS 
WHERE FAILURE OF THE SOFTWARE MAY CAUSE PERSONAL INJURY OR DEATH AND YOU AGREE 
THAT YOU ARE FULLY RESPONSIBLE FOR ANY CLAIMS, COSTS, DAMAGES, EXPENSES, AND 
ATTORNEYS’ FEES ARISING OUT OF ANY SUCH USE, EVEN IF ANY CLAIM ALLEGES THAT 
INTEL WAS NEGLIGENT REGARDING THE DESIGN OR MANUFACTURE OF THE SOFTWARE.

LIMITATION OF LIABILITY. IN NO EVENT WILL INTEL BE LIABLE FOR ANY DIRECT, 
INDIRECT, INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, 
BUT NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE, 
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY THEORY OF 
LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT (INCLUDING NEGLIGENCE 
OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF THIS SOFTWARE, EVEN IF 
ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.

No support.  Intel may make changes to the Software, at any time without notice, 
and is not obligated to support, update or provide training for the Software. 

Termination. Your right to use the Software is terminated in the event of your 
breach of this license.

Feedback.  Should you provide Intel with comments, modifications, corrections, 
enhancements or other input (“Feedback”) related to the Software, Intel will be 
free to use, disclose, reproduce, license or otherwise distribute or exploit the 
Feedback in its sole discretion without any obligations or restrictions of any 
kind, including without limitation, intellectual property rights or licensing 
obligations.

Compliance with laws.  You agree to comply with all relevant laws and regulations 
governing your use, transfer, import or export (or prohibition thereof) of the 
Software.

Governing law.  All disputes will be governed by the laws of the United States of 
America and the State of Delaware without reference to conflict of law 
principles and subject to the exclusive jurisdiction of the state or federal 
courts sitting in the State of Delaware, and each party agrees that it submits 
to the personal jurisdiction and venue of those courts and waives any 
objections. THE UNITED NATIONS CONVENTION ON CONTRACTS FOR THE INTERNATIONAL 
SALE OF GOODS (1980) IS SPECIFICALLY EXCLUDED AND WILL NOT APPLY TO THE 
SOFTWARE.
```

Third-party code inside oneMKL and its notices: `licenses/intel-onemkl-third-party-programs.txt` and
`licenses/intel-onemkl-third-party-programs-safestring.txt`.

### 5.3 Code whose licence the regenie source does not state

regenie's `external_libs/` contains three pieces of numerical code that carry no licence statement of their own and
are not mentioned in regenie's LICENSE. regenie-fast includes them unchanged, as the official regenie binaries do.

- **MVTDST** (`external_libs/mvtnorm`), multivariate normal and t probabilities by Alan Genz. The file header
  identifies it as the copy in the R package mvtnorm (revision 231, 2011), which is distributed under GPL-2. Alan
  Genz has also released his multivariate normal code under BSD-style terms elsewhere, for example in SciPy.
  Details: `licenses/mvtnorm.txt`.
- **qfc** (`external_libs/qf`), Robert Davies' algorithm AS 155 for linear combinations of chi-squared variables,
  taken from his web page and modified by the regenie authors. Neither the code nor the page states licence terms.
  Details: `licenses/qf.txt`.
- **QUADPACK and D1MACH** (`external_libs/quadpack`) from netlib. Neither the files nor netlib state a licence;
  QUADPACK is commonly described as public domain software. Details: `licenses/quadpack.txt`.

### 5.4 Acknowledgements required by some licences

- This product includes software developed by Computing Services at Carnegie Mellon University
  (http://www.cmu.edu/computing/). (Cyrus SASL, `lib/libsasl2.so.2`)
- This product includes software developed by the University of California, Berkeley and its contributors. (Code
  under the original BSD licence in some of the bundled libraries; see their copyright files.)
- Zstandard 1.1.0 (in both programs) is distributed with Facebook's "Additional Grant of Patent Rights Version 2",
  reproduced in `licenses/zstd-1.1.0.txt`.

### 5.5 No warranty

All components are distributed without any warranty, to the extent stated in their licences.

## 6. How this list was made

The files in `lib/` were identified by SHA-256 against the files installed in the Ubuntu 22.04 build image, and
their packages and versions were read with `dpkg -S` and `dpkg-query`. The statically linked components of
`regenie-4.1.3-fast` were taken from its build recipe (`fast/build/`, regenie's `CMakeLists.txt`) and checked
against the symbols and version strings in the binary. Those of `regenie-4.1.3-official` were read from its
symbols, version strings and dynamic-section entries, and its libgfortran and libquadmath code was compared with
the static libraries of Ubuntu's gcc-9 and gcc-11 packages (it matches gcc-9). The scripts that map `lib/` to
Ubuntu packages and download the GPL/LGPL source packages are in `fast/package/tools/` of the repository.
