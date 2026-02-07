/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _XT_TCPMSS_MATCH_H
#define _XT_TCPMSS_MATCH_H

#include <linux/types.h>

/* Target (TCPMSS): set MSS in TCP packets */
struct xt_tcpmss_info {
	__u16 mss;
};
#define XT_TCPMSS_CLAMP_PMTU 0xffff

/* Match (tcpmss): match MSS range */
struct xt_tcpmss_match_info {
	__u16 mss_min, mss_max;
	__u8 invert;
};

#endif /*_XT_TCPMSS_MATCH_H*/
