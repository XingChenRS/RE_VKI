/* SPDX-License-Identifier: GPL-2.0 WITH Linux-syscall-note */
#ifndef _XT_CONNMARK_H_target
#define _XT_CONNMARK_H_target

#include <linux/types.h>

/* Revision 1 */
enum {
	XT_CONNMARK_SET = 0,
	XT_CONNMARK_SAVE,
	XT_CONNMARK_RESTORE,
};

enum {
	D_SHIFT_LEFT,
	D_SHIFT_RIGHT,
};

struct xt_connmark_tginfo1 {
	__u32 ctmark, ctmask, nfmask;
	__u8 mode;
};

struct xt_connmark_tginfo2 {
	__u32 ctmark, ctmask, nfmask;
	__u8 mode;
	__u8 shift_dir, shift_bits;
};

struct xt_connmark_mtinfo1 {
	__u32 mark, mask;
	__u8 invert;
};

#endif /* _XT_CONNMARK_H_target */
