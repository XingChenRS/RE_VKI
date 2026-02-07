/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
/* TTL modification module for IP tables
 * (C) 2000 by Harald Welte <laforge@netfilter.org> */

#ifndef _IPT_TTL_H
#define _IPT_TTL_H

#include <linux/types.h>

/* Match: compare TTL (EQ/NE/LT/GT) - used by xt_HL.c */
enum {
	IPT_TTL_EQ = 0,
	IPT_TTL_NE,
	IPT_TTL_LT,
	IPT_TTL_GT,
	/* Target: set/inc/dec TTL */
	IPT_TTL_SET,
	IPT_TTL_INC,
	IPT_TTL_DEC
};

#define IPT_TTL_MAXMODE	IPT_TTL_DEC

struct ipt_ttl_info {
	__u8	mode;
	__u8	ttl;
};

struct ipt_TTL_info {
	__u8	mode;
	__u8	ttl;
};

#endif
