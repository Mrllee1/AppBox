.text
.globl _appbox_objectmapper_epilogue
.p2align 2
_appbox_objectmapper_epilogue:
  // The translated ObjectMapper cleanup path can resume at the LDP without
  // executing its preceding `sub sp, x29, #0x50`. Reconstruct the canonical
  // AArch64 frame address before restoring the saved frame pointer and LR.
  ldr x2, [x11, #0xe8]
  sub x2, x2, #0x50
  str x2, [x11, #0xf8]
  ldp x0, x1, [x2, #0x50]
  str x0, [x11, #0xe8]
  str x1, [x11, #0xf0]

  // Continue the adversarys direct-threaded dispatch protocol.
  ldr x9, [x28], #8
  mov w27, w9
  add x27, x27, x26
  br x27
