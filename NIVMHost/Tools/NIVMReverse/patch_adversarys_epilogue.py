#!/usr/bin/env python3
"""Install AppBox's guest-compatibility handlers in adversarys.

The handlers occupy an authenticated zero-filled code cave in the PlayBox
runtime and follow its direct-threaded ABI. Fuel can select them by their low
runtime offsets.
"""

from __future__ import annotations

import argparse
from pathlib import Path


HANDLER_OFFSET = 0x0088B6A8
HANDLER = bytes.fromhex(
    "627540f9"  # ldr x2, [x11, #0xe8]
    "424001d1"  # sub x2, x2, #0x50
    "627d00f9"  # str x2, [x11, #0xf8]
    "400445a9"  # ldp x0, x1, [x2, #0x50]
    "607500f9"  # str x0, [x11, #0xe8]
    "617900f9"  # str x1, [x11, #0xf0]
    "898740f8"  # ldr x9, [x28], #8
    "fb03092a"  # mov w27, w9
    "7b031a8b"  # add x27, x27, x26
    "60031fd6"  # br x27
)

NATIVE_OBJC_CALL_HANDLER_OFFSET = 0x0088B6D0
NATIVE_OBJC_CALL_HANDLER = bytes.fromhex(
    "fd7bbfa9"  # stp x29, x30, [sp, #-0x10]!
    "ee3fbfa9"  # stp x14, x15, [sp, #-0x10]!
    "f047bfa9"  # stp x16, x17, [sp, #-0x10]!
    "f353bfa9"  # stp x19, x20, [sp, #-0x10]!
    "f55bbfa9"  # stp x21, x22, [sp, #-0x10]!
    "f763bfa9"  # stp x23, x24, [sp, #-0x10]!
    "f96bbfa9"  # stp x25, x26, [sp, #-0x10]!
    "fb73bfa9"  # stp x27, x28, [sp, #-0x10]!
    "22fd60d3"  # lsr x2, x9, #32
    "4200118b"  # add x2, x2, x17
    "e1030caa"  # mov x1, x12
    "e0030baa"  # mov x0, x11
    "565bde97"  # bl adversarys+0x22458
    "fb73c1a8"  # ldp x27, x28, [sp], #0x10
    "f96bc1a8"  # ldp x25, x26, [sp], #0x10
    "f763c1a8"  # ldp x23, x24, [sp], #0x10
    "f55bc1a8"  # ldp x21, x22, [sp], #0x10
    "f353c1a8"  # ldp x19, x20, [sp], #0x10
    "f047c1a8"  # ldp x16, x17, [sp], #0x10
    "ee3fc1a8"  # ldp x14, x15, [sp], #0x10
    "fd7bc1a8"  # ldp x29, x30, [sp], #0x10
    "cb010191"  # add x11, x14, #0x40
    "0d2080d2"  # mov x13, #0x100
    "cc413391"  # add x12, x14, #0xcd0
    "8a0340f9"  # ldr x10, [x28]
    "e2030a2a"  # mov w2, w10
    "4afd60d3"  # lsr x10, x10, #32
    "4101118b"  # add x1, x10, x17
    "617900f9"  # str x1, [x11, #0xf0]
    "c1a100f9"  # str x1, [x14, #0x140]
    "0a58de17"  # b adversarys+0x21770
)

NATIVE_INDIRECT_CALL_HANDLER_OFFSET = 0x0088B750
NATIVE_INDIRECT_CALL_HANDLER = bytes.fromhex(
    "fd7bbfa9"  # stp x29, x30, [sp, #-0x10]!
    "ee3fbfa9"  # stp x14, x15, [sp, #-0x10]!
    "f047bfa9"  # stp x16, x17, [sp, #-0x10]!
    "f353bfa9"  # stp x19, x20, [sp, #-0x10]!
    "f55bbfa9"  # stp x21, x22, [sp, #-0x10]!
    "f763bfa9"  # stp x23, x24, [sp, #-0x10]!
    "f96bbfa9"  # stp x25, x26, [sp, #-0x10]!
    "fb73bfa9"  # stp x27, x28, [sp, #-0x10]!
    "229160d3"  # ubfx x2, x9, #32, #5
    "627962f8"  # ldr x2, [x11, x2, lsl #3]
    "e1030caa"  # mov x1, x12
    "e0030baa"  # mov x0, x11
    "365bde97"  # bl adversarys+0x22458
    "fb73c1a8"  # ldp x27, x28, [sp], #0x10
    "f96bc1a8"  # ldp x25, x26, [sp], #0x10
    "f763c1a8"  # ldp x23, x24, [sp], #0x10
    "f55bc1a8"  # ldp x21, x22, [sp], #0x10
    "f353c1a8"  # ldp x19, x20, [sp], #0x10
    "f047c1a8"  # ldp x16, x17, [sp], #0x10
    "ee3fc1a8"  # ldp x14, x15, [sp], #0x10
    "fd7bc1a8"  # ldp x29, x30, [sp], #0x10
    "cb010191"  # add x11, x14, #0x40
    "0d2080d2"  # mov x13, #0x100
    "cc413391"  # add x12, x14, #0xcd0
    "617940f9"  # ldr x1, [x11, #0xf0]
    "c1a100f9"  # str x1, [x14, #0x140]
    "7157de17"  # b adversarys+0x2157c (translated RET resolver)
)

# One-shot real-device probe for the native-tail ABI. It preserves the fuel
# register selector in X9, exposes the selected guest target in X17, the guest
# LR in X20 and the translated guest PC in X19, then traps for main.m's
# async-signal-safe diagnostic logger.
NATIVE_INDIRECT_CALL_PROBE = bytes.fromhex(
    "229160d3"  # ubfx x2, x9, #32, #5
    "717962f8"  # ldr x17, [x11, x2, lsl #3]
    "747940f9"  # ldr x20, [x11, #0xf0]
    "d3a140f9"  # ldr x19, [x14, #0x140]
    "000020d4"  # brk #0
)

FLUTTER_GUEST_REGISTER_PROBE_OFFSET = 0x0088BD20
FLUTTER_GUEST_REGISTER_PROBE = bytes.fromhex(
    "24ad67d3"  # ubfx x4, x9, #39, #5 (destination guest register)
    "25c16cd3"  # ubfx x5, x9, #44, #5 (base guest register)
    "737964f8"  # ldr x19, [x11, x4, lsl #3]
    "747965f8"  # ldr x20, [x11, x5, lsl #3]
    "d59d40f9"  # ldr x21, [x14, #0x138] (guest SP)
    "767940f9"  # ldr x22, [x11, #0xf0] (guest LR)
    "b73a40f9"  # ldr x23, [x21, #0x70]
    "b83e40f9"  # ldr x24, [x21, #0x78]
    "b94a40f9"  # ldr x25, [x21, #0x90]
    "ba4e40f9"  # ldr x26, [x21, #0x98]
    "bb5240f9"  # ldr x27, [x21, #0xa0]
    "000020d4"  # brk #0
)

# Native Swift associated-conformance callbacks can occur while a translated
# guest frame is active. AppBox precomputes Chungong's lazy metadata while the
# interpreter is idle, then redirects the guest's relative accessor field to
# this signed native stub.  The translated main image is always mapped at
# adversarys+0x62e4000; its accessor cache is at main+0x10e7a90.  Loading that
# cache directly keeps the signed runtime page immutable on device.
CHUNGONG_CACHED_CONFORMANCE_OFFSET = 0x0088B7C0
CHUNGONG_CACHED_CONFORMANCE_STUB = bytes.fromhex(
    "005a0390"  # adrp x0, adversarys+0x73cba90@page
    "004845f9"  # ldr x0, [x0, #0xa90]
    "c0035fd6"  # ret
)

# ObjectMapper.Mapper's deallocating deinitializer can be called by native
# Swift while Seal's translated AppDelegate is still active.  A nested guest
# entry reuses the interpreter state and leaves its LR at Seal+0x3e6000.  This
# signed no-op return stub is used only for that startup-time metadata slot;
# leaking the short-lived Mapper is safer than corrupting the guest machine.
CHUNGONG_OBJECTMAPPER_DEALLOC_OFFSET = 0x0088B7CC
CHUNGONG_OBJECTMAPPER_DEALLOC_STUB = bytes.fromhex(
    "c0035fd6"  # ret
)

# Seal+0x239a6c converts a Swift String into a small appearance enum and is
# reached as a native Swift callback while AppDelegate is translated.  The
# valid zero case is sufficient during bootstrap and avoids nested execution.
CHUNGONG_APPEARANCE_ENUM_OFFSET = 0x0088B7D0
CHUNGONG_APPEARANCE_ENUM_STUB = bytes.fromhex(
    "1f010039"  # strb wzr, [x8]
    "c0035fd6"  # ret
)

# Seal+0x239e78 is a lazy witness-table accessor. AppBox initializes it while
# the interpreter is idle, then redirects the relative Swift descriptor field
# to this signed cache load. The cache lives at translated main+0x10f6a60;
# main is mapped at adversarys+0x62e4000.
CHUNGONG_MODEL_WITNESS_OFFSET = 0x0088B7D8
CHUNGONG_MODEL_WITNESS_STUB = bytes.fromhex(
    "605a03f0"  # adrp x0, adversarys+0x73daa60@page
    "003045f9"  # ldr x0, [x0, #0xa60]
    "c0035fd6"  # ret
)

# Native equivalents for ObjectMapper's generic-class metadata callbacks.
# The first forwards all integer arguments to swift_allocateGenericClassMetadata.
# The other two reproduce EnumTransform/Mapper's calls to
# swift_initClassMetadata2, including Mapper's two field-offset descriptors.
# dlsym is reached through adversarys' signed import stub at +0x61a32d8.
CHUNGONG_SWIFT_METADATA_OFFSET = 0x0088B7E4
CHUNGONG_SWIFT_METADATA_STUBS = bytes.fromhex(
    "e007bba9e20f01a9e41702a9e61f03a9fd7b04a9fd03019120008092a1060010"
    "b55e6495f00300aafd7b44a9e61f43a9e41742a9e20f41a9e007c5a800021fd6"
    "ff0301d1fd7b03a9fdc30091e00f00f9ff1300f920008092c1050070a65e6495"
    "e50300aae00f40f9010080d2020080d2e383009104800191a0003fd61f0000f1"
    "21109f9afd7b43a9ff030191c0035fd6ff4301d1fd7b04a9fd030191e00f00f9"
    "486905d008e11e91496905d029411f91e82702a920008092c10200708e5e6495"
    "e50300aae00f40f9010080d2420080d2e383009104800191a0003fd61f0000f1"
    "21109f9afd7b44a9ff430191c0035fd673776966745f616c6c6f636174654765"
    "6e65726963436c6173734d657461646174610073776966745f696e6974436c61"
    "73734d657461646174613200"
)

# Seal+0x3e6098 is `sub sp, sp, #0x230`. The converted fuel currently uses a
# non-mutating placeholder, so the indirect result buffer overlaps the next
# ObjectMapper frame and overwrites its saved LR. This direct-threaded handler
# applies the missing guest-SP adjustment and advances to the next fuel word.
CHUNGONG_SUB_SP_0X230_OFFSET = 0x0088B910
CHUNGONG_SUB_SP_0X230_HANDLER = bytes.fromhex(
    "c09d40f9"  # ldr x0, [x14, #0x138]
    "00c008d1"  # sub x0, x0, #0x230
    "c09d00f9"  # str x0, [x14, #0x138]
    "898740f8"  # ldr x9, [x28], #8
    "fb03092a"  # mov w27, w9
    "7b031a8b"  # add x27, x27, x26
    "60031fd6"  # br x27
)

# Seal uses this exact ORR-immediate instruction to form Swift small-string
# values. The corpus conversion leaves all of its occurrences as the invalid
# 0x7000d2a3 placeholder. Fuel rewrites point those qwords at this handler.
CHUNGONG_ORR_X1_X8_HIGH_BIT_OFFSET = 0x0088B92C
CHUNGONG_ORR_X1_X8_HIGH_BIT_HANDLER = bytes.fromhex(
    "602140f9"  # ldr x0, [x11, #0x40] (guest x8)
    "000041b2"  # orr x0, x0, #0x8000000000000000
    "600500f9"  # str x0, [x11, #0x8] (guest x1)
    "898740f8"  # ldr x9, [x28], #8
    "fb03092a"  # mov w27, w9
    "7b031a8b"  # add x27, x27, x26
    "60031fd6"  # br x27
)

# Seal+0xe30b4 starts a Swift set/dictionary helper with
# `sub sp, sp, #0xc0`. Its converted block is the unresolved 0x7000de05
# placeholder, so install the same direct-threaded guest-SP adjustment used by
# the earlier ObjectMapper frame fix, with this function's exact frame size.
CHUNGONG_SUB_SP_0XC0_OFFSET = 0x0088B948
CHUNGONG_SUB_SP_0XC0_HANDLER = bytes.fromhex(
    "c09d40f9"  # ldr x0, [x14, #0x138]
    "000003d1"  # sub x0, x0, #0xc0
    "c09d00f9"  # str x0, [x14, #0x138]
    "898740f8"  # ldr x9, [x28], #8
    "fb03092a"  # mov w27, w9
    "7b031a8b"  # add x27, x27, x26
    "60031fd6"  # br x27
)

# Seal+0xe30b4..+0xe30f4 is one fuel basic block, not one instruction.  The
# v319 SP-only handler skipped its register saves, argument preparation and BL
# to Seal+0x8a50. This handler reproduces the complete guest block, derives LR
# from the current translated PC and reads the target-cursor delta from the
# fuel qword's high 32 bits, so all three identical Seal blocks can share it.
CHUNGONG_DICTIONARY_RESIZE_PROLOGUE_OFFSET = 0x0088B964
CHUNGONG_DICTIONARY_RESIZE_PROLOGUE_HANDLER = bytes.fromhex(
    "ca9d40f9"  # ldr x10, [x14, #0x138]
    "4a0103d1"  # sub x10, x10, #0xc0
    "ca9d00f9"  # str x10, [x14, #0x138]
    "607140f9"  # ldr x0, [x11, #0xe0] (guest x28)
    "616d40f9"  # ldr x1, [x11, #0xd8] (guest x27)
    "400506a9"  # stp x0, x1, [x10, #0x60]
    "606940f9"  # ldr x0, [x11, #0xd0] (guest x26)
    "616540f9"  # ldr x1, [x11, #0xc8] (guest x25)
    "400507a9"  # stp x0, x1, [x10, #0x70]
    "606140f9"  # ldr x0, [x11, #0xc0] (guest x24)
    "615d40f9"  # ldr x1, [x11, #0xb8] (guest x23)
    "400508a9"  # stp x0, x1, [x10, #0x80]
    "605940f9"  # ldr x0, [x11, #0xb0] (guest x22)
    "615540f9"  # ldr x1, [x11, #0xa8] (guest x21)
    "400509a9"  # stp x0, x1, [x10, #0x90]
    "605140f9"  # ldr x0, [x11, #0xa0] (guest x20)
    "614d40f9"  # ldr x1, [x11, #0x98] (guest x19)
    "40050aa9"  # stp x0, x1, [x10, #0xa0]
    "607540f9"  # ldr x0, [x11, #0xe8] (guest x29)
    "617940f9"  # ldr x1, [x11, #0xf0] (guest x30)
    "40050ba9"  # stp x0, x1, [x10, #0xb0]
    "40c10291"  # add x0, x10, #0xb0
    "607500f9"  # str x0, [x11, #0xe8]
    "605140f9"  # ldr x0, [x11, #0xa0]
    "604d00f9"  # str x0, [x11, #0x98]
    "610540f9"  # ldr x1, [x11, #0x8]
    "615500f9"  # str x1, [x11, #0xa8]
    "020040f9"  # ldr x2, [x0]
    "626500f9"  # str x2, [x11, #0xc8]
    "430c40f9"  # ldr x3, [x2, #0x18]
    "632100f9"  # str x3, [x11, #0x40]
    "640140f9"  # ldr x4, [x11]
    "7f0004eb"  # cmp x3, x4
    "65c0849a"  # csel x5, x3, x4, gt
    "655100f9"  # str x5, [x11, #0xa0]
    "660940f9"  # ldr x6, [x11, #0x10]
    "670d40f9"  # ldr x7, [x11, #0x18]
    "660100f9"  # str x6, [x11]
    "670500f9"  # str x7, [x11, #0x8]
    "c8a140f9"  # ldr x8, [x14, #0x140] (translated guest PC)
    "08110191"  # add x8, x8, #0x44 (guest LR)
    "1f2003d5"  # nop (preserve installed handler size)
    "687900f9"  # str x8, [x11, #0xf0]
    "29fd60d3"  # lsr x9, x9, #32 (fuel target-cursor delta)
    "9c0309cb"  # sub x28, x28, x9
    "1f2003d5"  # nop (preserve installed handler size)
    "898740f8"  # ldr x9, [x28], #0x8
    "fb03092a"  # mov w27, w9
    "7b031a8b"  # add x27, x27, x26
    "60031fd6"  # br x27
)

# Seal+0xd2c254..+0xd2c26c packs an OS version tuple on the guest stack and
# calls libxpc's private availability checker.  The converted block is one
# unresolved qword.  The handler includes its dlsym string after the code,
# calls the native implementation with a preserved interpreter context, and
# resumes the sequential fuel block at Seal+0xd2c270.
CHUNGONG_AVAILABILITY_VERSION_CHECK_OFFSET = 0x0088BA2C
CHUNGONG_AVAILABILITY_VERSION_CHECK_HANDLER = bytes.fromhex(
    "680940b9083d1053691140b9281d1833691940b9281d0033ca9d40f9690140b9"
    "492100296a0500f929008052690100f9084e80d228e0a0f24803088b687900f9"
    "fd7bbfa9ee3fbfa9f047bfa9f353bfa9f55bbfa9f763bfa9f96bbfa9fb73bfa9"
    "20008092c1030010105b86d250c3a0f2fa0f40f95003108b00023fd6f00300aa"
    "ee3340f9cb010191600140f9610540f900023fd6ee3340f9cb010191600100f9"
    "fb73c1a8f96bc1a8f763c1a8f55bc1a8f353c1a8f047c1a8ee3fc1a8fd7bc1a8"
    "cb0101910d2080d2cc413391898740f8fb03092a7b031a8b60031fd6"
    "5f617661696c6162696c6974795f76657273696f6e5f636865636b00"
)

# Swift nominal-type descriptors store their metadata accessor as a signed
# 32-bit relative pointer.  adversarys can slide more than 2 GiB away from the
# AppBox executable, so a descriptor cannot reliably point at a host function.
# These signed in-runtime stubs return a metadata pointer from reserved slots
# in adversarys' writable __DATA,__common gap immediately before the first
# mapped guest image.  AppBox prewarms and fills those slots before guest code
# starts, so no executable page is modified after code signing.
CHUNGONG_KINGFISHER_WRAPPER_METADATA_OFFSET = 0x0088BB28
CHUNGONG_KINGFISHER_IMAGE_RESOURCE_METADATA_OFFSET = 0x0088BB40
CHUNGONG_KINGFISHER_DOWNLOAD_TASK_METADATA_OFFSET = 0x0088BB58
CHUNGONG_KINGFISHER_WRAPPER_METADATA_STUB = bytes.fromhex(
    "c8d20290"  # adrp x8, adversarys+0x62e3000
    "00e147f9"  # ldr x0, [x8, #0xfc0]
    "010080d2"  # mov x1, #0x0
    "c0035fd6"  # ret
)
CHUNGONG_KINGFISHER_IMAGE_RESOURCE_METADATA_STUB = bytes.fromhex(
    "c8d20290"  # adrp x8, adversarys+0x62e3000
    "00e547f9"  # ldr x0, [x8, #0xfc8]
    "010080d2"  # mov x1, #0x0
    "c0035fd6"  # ret
)
CHUNGONG_KINGFISHER_DOWNLOAD_TASK_METADATA_STUB = bytes.fromhex(
    "c8d20290"  # adrp x8, adversarys+0x62e3000
    "00e947f9"  # ldr x0, [x8, #0xfd0]
    "010080d2"  # mov x1, #0x0
    "c0035fd6"  # ret
)

# adversarys_d funnels direct system calls made by translated guest code
# through a single `svc #0x80`.  The Chungong guest executes
# ptrace(PT_DENY_ATTACH) followed by exit(-1) during its earliest static
# initializers; forwarding those calls terminates the whole AppBox host.  The
# guest reaches a stable UI when this translated raw-syscall gateway reports
# success instead.  Calls made normally through the host's signed libSystem
# remain unaffected.
SYSCALL_GATE_OFFSET = 0x000226A8
SYSCALL_GATE_ORIGINAL = bytes.fromhex("011000d4")  # svc #0x80
SYSCALL_GATE_REPLACEMENT = bytes.fromhex("000080d2")  # mov x0, #0

# Diagnostic-only replacement for adversarys' signal/crash-reporting wrapper.
# The stock wrapper can fault recursively while formatting the first guest
# exception, obscuring the original signal context with a stack overflow.  A
# BRK here lets LLDB stop at the first wrapper entry with x0/x1 still intact.
CRASH_REPORT_WRAPPER_OFFSET = 0x00021AE8
CRASH_REPORT_WRAPPER_ORIGINAL = bytes.fromhex("f44fbea9")
CRASH_REPORT_WRAPPER_TRAP = bytes.fromhex("000020d4")  # brk #0

# Swift's generated iOS main calls UIApplicationMain and then tears down the
# Swift arguments before unconditionally calling _exit if UIApplicationMain
# returns. PBPlayerKit intentionally returns from its guest UIApplicationMain
# hook after installing the guest delegate, so translated apps hand control to
# AppBox's UIKit run loop instead of entering that teardown. Resolve the host
# callback through adversarys' existing signed dlsym import; no runtime data
# slot is borrowed or mutated.
GUEST_MAIN_LOOP_WAIT_OFFSET = 0x0088BC00
GUEST_MAIN_LOOP_WAIT_HANDLER = bytes.fromhex(
    "80008092"  # mov x0, #-5 (RTLD_MAIN_ONLY)
    "e1000010"  # adr x1, adversarys+0x88bc20
    "b45d6495"  # bl adversarys+0x61a32d8 (_dlsym import stub)
    "000020d4"  # diagnostic: trap with the resolved callback in x0
    "000020d4"  # brk #0 if the callback contract is violated
    "000000000000000000000000"  # keep callback name at +0x20
    "417070426f78456e74657247756573744d61696e4c6f6f7000"
)

# Diagnostic-only direct-threaded replacement for Libbox's stores to the Go
# global run-queue length.  It preserves the stock STR Wt,[Xn,#0x2c0]
# semantics for sane queue lengths and traps before committing the first
# impossible value.  The Fuel diagnostic rewrites only the 14 statically
# proven run-queue writer qwords to this otherwise-unused code-cave handler.
GO_RUNQ_STORE_DIAGNOSTIC_OFFSET = 0x0088BC50
GO_RUNQ_STORE_DIAGNOSTIC_HANDLER = bytes.fromhex(
    "24ad67d3"  # ubfx x4, x9, #39, #5 (value guest register)
    "607964f8"  # ldr x0, [x11, x4, lsl #3]
    "25c16cd3"  # ubfx x5, x9, #44, #5 (base guest register)
    "617965f8"  # ldr x1, [x11, x5, lsl #3]
    "1f404071"  # cmp w0, #0x10, lsl #12
    "c2000054"  # b.hs trap
    "20c002b9"  # str w0, [x1, #0x2c0]
    "898740f8"  # ldr x9, [x28], #8
    "fb03092a"  # mov w27, w9
    "7b031a8b"  # add x27, x27, x26
    "60031fd6"  # br x27
    "000020d4"  # trap: brk #0
)

# Scalar unsigned-immediate loads with Rt=31 access memory but discard the
# value.  The stock handler family has zero-destination variants for only some
# immediates; selecting a general handler for an unseen immediate writes the
# result into adversarys' virtual-SP slot.  These four width-specific handlers
# take Xn from fuel bits 32...36 and a byte offset from bits 37 and above.
ZERO_DESTINATION_LDR_X_OFFSET = 0x0088BC80
ZERO_DESTINATION_LDR_W_OFFSET = 0x0088BCA0
ZERO_DESTINATION_LDR_H_OFFSET = 0x0088BCC0
ZERO_DESTINATION_LDR_B_OFFSET = 0x0088BCE0
ZERO_DESTINATION_LOAD_COMMON_PREFIX = bytes.fromhex(
    "249160d3"  # ubfx x4, x9, #32, #5
    "607964f8"  # ldr x0, [x11, x4, lsl #3]
    "21fd65d3"  # lsr x1, x9, #37
)
ZERO_DESTINATION_LOAD_COMMON_SUFFIX = bytes.fromhex(
    "898740f8"  # ldr x9, [x28], #8
    "fb03092a"  # mov w27, w9
    "7b031a8b"  # add x27, x27, x26
    "60031fd6"  # br x27
)
ZERO_DESTINATION_LDR_X_HANDLER = (
    ZERO_DESTINATION_LOAD_COMMON_PREFIX
    + bytes.fromhex("1f6861f8")  # ldr xzr, [x0, x1]
    + ZERO_DESTINATION_LOAD_COMMON_SUFFIX
)
ZERO_DESTINATION_LDR_W_HANDLER = (
    ZERO_DESTINATION_LOAD_COMMON_PREFIX
    + bytes.fromhex("1f6861b8")  # ldr wzr, [x0, x1]
    + ZERO_DESTINATION_LOAD_COMMON_SUFFIX
)
ZERO_DESTINATION_LDR_H_HANDLER = (
    ZERO_DESTINATION_LOAD_COMMON_PREFIX
    + bytes.fromhex("1f686178")  # ldrh wzr, [x0, x1]
    + ZERO_DESTINATION_LOAD_COMMON_SUFFIX
)
ZERO_DESTINATION_LDR_B_HANDLER = (
    ZERO_DESTINATION_LOAD_COMMON_PREFIX
    + bytes.fromhex("1f686138")  # ldrb wzr, [x0, x1]
    + ZERO_DESTINATION_LOAD_COMMON_SUFFIX
)

# adversarys' generic native-call bridge restores X0...X9 from the guest and
# invokes the resolved system function at +0x22574.  dispatch_once_f accepts a
# callback in X2, so a raw guest function pointer there would bypass the
# interpreter and trigger iOS' executable-page protection.  This signed code
# cave compares X2 with a profile-specific raw callback slot, replaces it with
# the prebuilt adversarys trampoline when equal, performs the original BLR and
# returns to +0x22578.  AppBox fills the two writable __common slots only for
# the exact Tianya 20.0.0+348 guest; every other call remains byte-for-byte
# equivalent to the stock bridge.
TIANYA_NATIVE_CALLBACK_BRIDGE_OFFSET = 0x0088BD50
TIANYA_NATIVE_CALLBACK_BRIDGE = bytes.fromhex(
    "c9d20290"  # adrp x9, adversarys+0x62e3000
    "2aed47f9"  # ldr x10, [x9, #0xfd8] (raw guest callback)
    "5f000aeb"  # cmp x2, x10
    "41000054"  # b.ne +0x8
    "22f147f9"  # ldr x2, [x9, #0xfe0] (signed callback trampoline)
    "20023fd6"  # blr x17 (original native target)
    "045ade17"  # b adversarys+0x22578
)
GENERIC_NATIVE_CALL_OFFSET = 0x00022574
GENERIC_NATIVE_CALL_ORIGINAL = bytes.fromhex("20023fd6")  # blr x17
GENERIC_NATIVE_CALL_REPLACEMENT = bytes.fromhex("f7a52114")  # b +0x8687dc

# Temporary conversion diagnostic: stop before adversarys aborts because an
# indirect guest address did not resolve to a registered image/PC-map entry.
MISSING_IMAGE_ABORT_OFFSET = 0x00008D38
MISSING_IMAGE_ABORT_ORIGINAL = bytes.fromhex("02698695")
MISSING_IMAGE_ABORT_TRAP = bytes.fromhex("000020d4")  # brk #0

def install_handler(
    image: bytearray, offset: int, handler: bytes, name: str
) -> str:
    end = offset + len(handler)
    if end > len(image):
        raise ValueError(f"adversarys image is shorter than {name} code cave")
    existing = bytes(image[offset:end])
    if existing == handler:
        return f"{name}_ALREADY_PATCHED offset={offset:#x}"
    if existing != bytes(len(handler)):
        raise ValueError(
            f"adversarys code cave is not empty at {offset:#x}: "
            f"{existing.hex()}"
        )
    image[offset:end] = handler
    return f"{name}_PATCHED offset={offset:#x} bytes={len(handler)}"


def replace_instruction(
    image: bytearray,
    offset: int,
    original: bytes,
    replacement: bytes,
    name: str,
) -> str:
    if len(original) != len(replacement):
        raise ValueError(f"{name} replacement must preserve instruction size")
    end = offset + len(original)
    if end > len(image):
        raise ValueError(f"adversarys image is shorter than {name}")
    existing = bytes(image[offset:end])
    if existing == replacement:
        return f"{name}_ALREADY_PATCHED offset={offset:#x}"
    if existing != original:
        raise ValueError(
            f"adversarys {name} mismatch at {offset:#x}: {existing.hex()}"
        )
    image[offset:end] = replacement
    return f"{name}_PATCHED offset={offset:#x} bytes={len(replacement)}"


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("runtime", type=Path)
    parser.add_argument(
        "--diagnostic-crash-wrapper-trap",
        action="store_true",
        help="replace the recursive crash-report wrapper entry with BRK #0",
    )
    parser.add_argument(
        "--diagnostic-native-indirect-probe",
        action="store_true",
        help="trap after exposing the selected native-tail target and guest LR",
    )
    parser.add_argument(
        "--diagnostic-flutter-register-probe",
        action="store_true",
        help="install a one-shot guest-register probe for a patched Fuel PC",
    )
    arguments = parser.parse_args()

    image = bytearray(arguments.runtime.read_bytes())
    try:
        messages = [
            install_handler(
                image, HANDLER_OFFSET, HANDLER, "ADVERSARYS_EPILOGUE"
            ),
            install_handler(
                image,
                NATIVE_OBJC_CALL_HANDLER_OFFSET,
                NATIVE_OBJC_CALL_HANDLER,
                "ADVERSARYS_NATIVE_OBJC_CALL",
            ),
            install_handler(
                image,
                NATIVE_INDIRECT_CALL_HANDLER_OFFSET,
                NATIVE_INDIRECT_CALL_HANDLER,
                "ADVERSARYS_NATIVE_INDIRECT_CALL",
            ),
            install_handler(
                image,
                CHUNGONG_CACHED_CONFORMANCE_OFFSET,
                CHUNGONG_CACHED_CONFORMANCE_STUB,
                "ADVERSARYS_CHUNGONG_CACHED_CONFORMANCE",
            ),
            install_handler(
                image,
                CHUNGONG_OBJECTMAPPER_DEALLOC_OFFSET,
                CHUNGONG_OBJECTMAPPER_DEALLOC_STUB,
                "ADVERSARYS_CHUNGONG_OBJECTMAPPER_DEALLOC",
            ),
            install_handler(
                image,
                CHUNGONG_APPEARANCE_ENUM_OFFSET,
                CHUNGONG_APPEARANCE_ENUM_STUB,
                "ADVERSARYS_CHUNGONG_APPEARANCE_ENUM",
            ),
            install_handler(
                image,
                CHUNGONG_MODEL_WITNESS_OFFSET,
                CHUNGONG_MODEL_WITNESS_STUB,
                "ADVERSARYS_CHUNGONG_MODEL_WITNESS",
            ),
            install_handler(
                image,
                CHUNGONG_SWIFT_METADATA_OFFSET,
                CHUNGONG_SWIFT_METADATA_STUBS,
                "ADVERSARYS_CHUNGONG_SWIFT_METADATA",
            ),
            install_handler(
                image,
                CHUNGONG_SUB_SP_0X230_OFFSET,
                CHUNGONG_SUB_SP_0X230_HANDLER,
                "ADVERSARYS_CHUNGONG_SUB_SP_0X230",
            ),
            install_handler(
                image,
                CHUNGONG_ORR_X1_X8_HIGH_BIT_OFFSET,
                CHUNGONG_ORR_X1_X8_HIGH_BIT_HANDLER,
                "ADVERSARYS_CHUNGONG_ORR_X1_X8_HIGH_BIT",
            ),
            install_handler(
                image,
                CHUNGONG_SUB_SP_0XC0_OFFSET,
                CHUNGONG_SUB_SP_0XC0_HANDLER,
                "ADVERSARYS_CHUNGONG_SUB_SP_0XC0",
            ),
            install_handler(
                image,
                CHUNGONG_DICTIONARY_RESIZE_PROLOGUE_OFFSET,
                CHUNGONG_DICTIONARY_RESIZE_PROLOGUE_HANDLER,
                "ADVERSARYS_CHUNGONG_DICTIONARY_RESIZE_PROLOGUE",
            ),
            install_handler(
                image,
                CHUNGONG_AVAILABILITY_VERSION_CHECK_OFFSET,
                CHUNGONG_AVAILABILITY_VERSION_CHECK_HANDLER,
                "ADVERSARYS_CHUNGONG_AVAILABILITY_VERSION_CHECK",
            ),
            install_handler(
                image,
                CHUNGONG_KINGFISHER_WRAPPER_METADATA_OFFSET,
                CHUNGONG_KINGFISHER_WRAPPER_METADATA_STUB,
                "ADVERSARYS_CHUNGONG_KINGFISHER_WRAPPER_METADATA",
            ),
            install_handler(
                image,
                CHUNGONG_KINGFISHER_IMAGE_RESOURCE_METADATA_OFFSET,
                CHUNGONG_KINGFISHER_IMAGE_RESOURCE_METADATA_STUB,
                "ADVERSARYS_CHUNGONG_KINGFISHER_IMAGE_RESOURCE_METADATA",
            ),
            install_handler(
                image,
                CHUNGONG_KINGFISHER_DOWNLOAD_TASK_METADATA_OFFSET,
                CHUNGONG_KINGFISHER_DOWNLOAD_TASK_METADATA_STUB,
                "ADVERSARYS_CHUNGONG_KINGFISHER_DOWNLOAD_TASK_METADATA",
            ),
            install_handler(
                image,
                GUEST_MAIN_LOOP_WAIT_OFFSET,
                GUEST_MAIN_LOOP_WAIT_HANDLER,
                "ADVERSARYS_GUEST_MAIN_LOOP_WAIT",
            ),
            install_handler(
                image,
                GO_RUNQ_STORE_DIAGNOSTIC_OFFSET,
                GO_RUNQ_STORE_DIAGNOSTIC_HANDLER,
                "ADVERSARYS_GO_RUNQ_STORE_DIAGNOSTIC",
            ),
            install_handler(
                image,
                ZERO_DESTINATION_LDR_X_OFFSET,
                ZERO_DESTINATION_LDR_X_HANDLER,
                "ADVERSARYS_ZERO_DESTINATION_LDR_X",
            ),
            install_handler(
                image,
                ZERO_DESTINATION_LDR_W_OFFSET,
                ZERO_DESTINATION_LDR_W_HANDLER,
                "ADVERSARYS_ZERO_DESTINATION_LDR_W",
            ),
            install_handler(
                image,
                ZERO_DESTINATION_LDR_H_OFFSET,
                ZERO_DESTINATION_LDR_H_HANDLER,
                "ADVERSARYS_ZERO_DESTINATION_LDR_H",
            ),
            install_handler(
                image,
                ZERO_DESTINATION_LDR_B_OFFSET,
                ZERO_DESTINATION_LDR_B_HANDLER,
                "ADVERSARYS_ZERO_DESTINATION_LDR_B",
            ),
            replace_instruction(
                image,
                SYSCALL_GATE_OFFSET,
                SYSCALL_GATE_ORIGINAL,
                SYSCALL_GATE_REPLACEMENT,
                "ADVERSARYS_SYSCALL_GATE",
            ),
            replace_instruction(
                image,
                MISSING_IMAGE_ABORT_OFFSET,
                MISSING_IMAGE_ABORT_ORIGINAL,
                MISSING_IMAGE_ABORT_TRAP,
                "ADVERSARYS_MISSING_IMAGE_DIAGNOSTIC",
            ),
        ]
        if arguments.diagnostic_crash_wrapper_trap:
            messages.append(
                replace_instruction(
                    image,
                    CRASH_REPORT_WRAPPER_OFFSET,
                    CRASH_REPORT_WRAPPER_ORIGINAL,
                    CRASH_REPORT_WRAPPER_TRAP,
                    "ADVERSARYS_CRASH_REPORT_WRAPPER",
                )
            )
        if arguments.diagnostic_native_indirect_probe:
            messages.append(
                replace_instruction(
                    image,
                    NATIVE_INDIRECT_CALL_HANDLER_OFFSET,
                    NATIVE_INDIRECT_CALL_HANDLER[:len(NATIVE_INDIRECT_CALL_PROBE)],
                    NATIVE_INDIRECT_CALL_PROBE,
                    "ADVERSARYS_NATIVE_INDIRECT_CALL_PROBE",
                )
            )
        if arguments.diagnostic_flutter_register_probe:
            messages.append(
                install_handler(
                    image,
                    FLUTTER_GUEST_REGISTER_PROBE_OFFSET,
                    FLUTTER_GUEST_REGISTER_PROBE,
                    "ADVERSARYS_FLUTTER_GUEST_REGISTER_PROBE",
                )
            )
    except ValueError as error:
        parser.error(str(error))
    arguments.runtime.write_bytes(image)
    for message in messages:
        print(message)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
