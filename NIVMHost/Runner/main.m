#import <Foundation/Foundation.h>
#import <UIKit/UIKit.h>
#import <UserNotifications/UserNotifications.h>
#import <CoreFoundation/CoreFoundation.h>
#import <dlfcn.h>
#import <objc/message.h>
#import <objc/runtime.h>
#include <mach/mach.h>
#include <mach/arm/thread_status.h>
#include <mach-o/dyld.h>
#include <mach-o/loader.h>
#include <mach-o/nlist.h>
#include <libgen.h>
#include <signal.h>
#include <stdlib.h>
#include <string.h>
#include <arpa/inet.h>
#include <errno.h>
#include <execinfo.h>
#include <fcntl.h>
#include <sys/socket.h>
#include <sys/time.h>
#include <sys/ucontext.h>
#include <unistd.h>

typedef void (*AppBoxNUDGuestHooksInitFunction)(void);
typedef void (*AppBoxPBPlayerSetupAppFunction)(void);
typedef void *(*AppBoxAdversarysOpenFunction)(const char *, const char *);
typedef void *(*AppBoxAdversarysOpenLooseFunction)(const char *);
typedef void *(*AppBoxAdversarysSymbolFunction)(void *, const char *);
typedef const char *(*AppBoxAdversarysErrorFunction)(void);
typedef void (*AppBoxAdversarysClassFunction)(const char *);
typedef void (*AppBoxAdversarysAbortFunction)(int);
typedef void (*AppBoxAdversarysHandlerFunction)(void (*)(const char *));
typedef void (*AppBoxSwiftRegisterRangeFunction)(const void *, const void *);

extern void AppBoxProbeLNKiwiDecrypt(const char *input);

static AppBoxNUDGuestHooksInitFunction AppBoxNUDGuestHooksInit;
static AppBoxPBPlayerSetupAppFunction AppBoxPBPlayerSetupApp;
static AppBoxAdversarysOpenFunction AppBoxAdversarysOpen;
static AppBoxAdversarysOpenLooseFunction AppBoxAdversarysOpenLoose;
static AppBoxAdversarysSymbolFunction AppBoxAdversarysSymbol;
static AppBoxAdversarysErrorFunction AppBoxAdversarysError;
static AppBoxAdversarysClassFunction AppBoxAdversarysClass;
static AppBoxAdversarysAbortFunction AppBoxAdversarysAbort;
static AppBoxAdversarysHandlerFunction AppBoxAdversarysHandler;
static uintptr_t AppBoxDiagnosticAdversarysBase;
static int AppBoxDiagnosticSignalFile = -1;
static BOOL AppBoxDiagnosticDispatchOnceArmed;
static volatile sig_atomic_t AppBoxDiagnosticWatchArmed;
static uintptr_t AppBoxDiagnosticWatchAddress;
static uintptr_t AppBoxDiagnosticWatchGuestState;
static volatile sig_atomic_t AppBoxDiagnosticSampleCount;
static const sig_atomic_t AppBoxDiagnosticSampleLimit = 5000;
static volatile int AppBoxDiagnosticBurstStarted;
static volatile int AppBoxDiagnosticFileBurstStarted;
static volatile int AppBoxDiagnosticFocusedBurstStarted;
static BOOL AppBoxDiagnosticFirstFrameHooked;
static IMP AppBoxOriginalKiwiInitWithListener;
static Class AppBoxNativeKiwiClass;
static IMP AppBoxNativeKiwiInit;
static IMP AppBoxOriginalDyzbKiwiInitEx;
static Class AppBoxNativeYunCengPluginClass;
static Class AppBoxNativeFlutterMethodChannelClass;
static char AppBoxNativeYunCengPluginAssociationKey;
static char AppBoxNativeYunCengTokenAssociationKey;
static char AppBoxNativeYunCengChannelAssociationKey;
static char AppBoxNativeYunCengHandlerAssociationKey;
static BOOL AppBoxInProcessGuestBootstrap;
static id AppBoxInProcessGuestDelegate;
static UIWindow *AppBoxInProcessGuestWindow;
static UIViewController *AppBoxInProcessGuestRootController;
static NSBundle *AppBoxGuestMainBundle;
static NSBundle *AppBoxHostBundle;
static NSMutableArray<NSValue *> *AppBoxLooseGuestImages;
static uintptr_t AppBoxChungongKingfisherBase;

typedef struct {
  uintptr_t value;
  uintptr_t state;
} AppBoxChungongMetadataResponse;

typedef AppBoxChungongMetadataResponse
    (*AppBoxSwiftGetGenericMetadataFunction)(
        uintptr_t, const void *const *, const void *);

static AppBoxSwiftGetGenericMetadataFunction
    AppBoxChungongSwiftGetGenericMetadata;
static const void *AppBoxChungongKingfisherWrapperDescriptor;
typedef AppBoxChungongMetadataResponse
    (*AppBoxSwiftGetSingletonMetadataFunction)(uintptr_t, const void *);
static AppBoxSwiftGetSingletonMetadataFunction
    AppBoxChungongSwiftGetSingletonMetadata;
static const void *AppBoxChungongKingfisherImageResourceDescriptor;

static AppBoxChungongMetadataResponse
AppBoxChungongKingfisherWrapperMetadataAccessor(
    uintptr_t request, const void *argument0, const void *argument1,
    const void *argument2) {
  if (AppBoxChungongSwiftGetGenericMetadata == NULL ||
      AppBoxChungongKingfisherWrapperDescriptor == NULL) {
    AppBoxChungongMetadataResponse failure = {0, 0};
    return failure;
  }
  const void *arguments[3] = {argument0, argument1, argument2};
  return AppBoxChungongSwiftGetGenericMetadata(
      request, arguments, AppBoxChungongKingfisherWrapperDescriptor);
}

static AppBoxChungongMetadataResponse
AppBoxChungongKingfisherImageResourceMetadataAccessor(uintptr_t request) {
  if (AppBoxChungongKingfisherBase == 0 ||
      AppBoxChungongSwiftGetSingletonMetadata == NULL ||
      AppBoxChungongKingfisherImageResourceDescriptor == NULL) {
    AppBoxChungongMetadataResponse failure = {0, 0};
    return failure;
  }
  const void *cached = *(const void *const *)(
      AppBoxChungongKingfisherBase + 0x000D63F0);
  if (cached != NULL) {
    AppBoxChungongMetadataResponse response = {
        (uintptr_t)cached, 0};
    return response;
  }
  return AppBoxChungongSwiftGetSingletonMetadata(
      request, AppBoxChungongKingfisherImageResourceDescriptor);
}

static AppBoxChungongMetadataResponse
AppBoxChungongKingfisherDownloadTaskMetadataAccessor(uintptr_t request) {
  (void)request;
  AppBoxChungongMetadataResponse response = {
      AppBoxChungongKingfisherBase + 0x000C8F68, 0};
  return response;
}

typedef struct {
  AppBoxSwiftRegisterRangeFunction registerProtocols;
  AppBoxSwiftRegisterRangeFunction registerConformances;
  AppBoxSwiftRegisterRangeFunction registerTypes;
  NSUInteger images;
  NSUInteger protocolSections;
  NSUInteger conformanceSections;
  NSUInteger typeSections;
} AppBoxSwiftRegistrationContext;

static BOOL AppBoxMachONameEquals(const char rawName[16],
                                  const char *expected) {
  size_t length = strlen(expected);
  return length <= 16 && memcmp(rawName, expected, length) == 0 &&
      (length == 16 || rawName[length] == '\0');
}

static BOOL AppBoxRegisterSwiftMetadataForImage(
    uintptr_t headerAddress,
    uintptr_t allowedStart,
    uintptr_t allowedEnd,
    AppBoxSwiftRegistrationContext *context) {
  const struct mach_header_64 *header =
      (const struct mach_header_64 *)headerAddress;
  if (header->magic != MH_MAGIC_64 || header->cputype != CPU_TYPE_ARM64 ||
      (header->filetype != MH_EXECUTE && header->filetype != MH_DYLIB &&
       header->filetype != MH_BUNDLE) ||
      header->ncmds == 0 || header->ncmds > 1024 ||
      header->sizeofcmds > 0x20000) {
    return NO;
  }

  const uint8_t *commands = (const uint8_t *)(header + 1);
  const uint8_t *commandsEnd = commands + header->sizeofcmds;
  const struct segment_command_64 *textSegment = NULL;
  for (uint32_t index = 0; index < header->ncmds; index++) {
    if (commands + sizeof(struct load_command) > commandsEnd) {
      return NO;
    }
    const struct load_command *command =
        (const struct load_command *)commands;
    if (command->cmdsize < sizeof(struct load_command) ||
        commands + command->cmdsize > commandsEnd) {
      return NO;
    }
    if (command->cmd == LC_SEGMENT_64 &&
        command->cmdsize >= sizeof(struct segment_command_64)) {
      const struct segment_command_64 *segment =
          (const struct segment_command_64 *)command;
      if (AppBoxMachONameEquals(segment->segname, SEG_TEXT) &&
          segment->fileoff == 0) {
        textSegment = segment;
      }
    }
    commands += command->cmdsize;
  }
  if (textSegment == NULL || textSegment->vmaddr > headerAddress) {
    return NO;
  }

  uintptr_t slide = headerAddress - (uintptr_t)textSegment->vmaddr;
  commands = (const uint8_t *)(header + 1);
  BOOL registeredImage = NO;
  for (uint32_t index = 0; index < header->ncmds; index++) {
    const struct load_command *command =
        (const struct load_command *)commands;
    if (command->cmd == LC_SEGMENT_64 &&
        command->cmdsize >= sizeof(struct segment_command_64)) {
      const struct segment_command_64 *segment =
          (const struct segment_command_64 *)command;
      size_t requiredSize = sizeof(struct segment_command_64) +
          (size_t)segment->nsects * sizeof(struct section_64);
      if (requiredSize > command->cmdsize) {
        return NO;
      }
      const struct section_64 *sections =
          (const struct section_64 *)(segment + 1);
      for (uint32_t sectionIndex = 0;
           sectionIndex < segment->nsects;
           sectionIndex++) {
        const struct section_64 *section = &sections[sectionIndex];
        if (section->size == 0 || section->addr > UINTPTR_MAX - slide) {
          continue;
        }
        uintptr_t beginAddress = slide + (uintptr_t)section->addr;
        if (beginAddress < allowedStart || beginAddress >= allowedEnd ||
            section->size > allowedEnd - beginAddress) {
          continue;
        }
        const void *begin = (const void *)beginAddress;
        const void *end = (const void *)(beginAddress + section->size);
        if (AppBoxMachONameEquals(section->sectname, "__swift5_protos") &&
            context->registerProtocols != NULL) {
          context->registerProtocols(begin, end);
          context->protocolSections++;
          registeredImage = YES;
        } else if (AppBoxMachONameEquals(section->sectname,
                                         "__swift5_proto") &&
                   context->registerConformances != NULL) {
          context->registerConformances(begin, end);
          context->conformanceSections++;
          registeredImage = YES;
        } else if (AppBoxMachONameEquals(section->sectname,
                                         "__swift5_types") &&
                   context->registerTypes != NULL) {
          context->registerTypes(begin, end);
          context->typeSections++;
          registeredImage = YES;
        }
      }
    }
    commands += command->cmdsize;
  }
  if (registeredImage) {
    context->images++;
  }
  return registeredImage;
}

static BOOL AppBoxRegisterMappedGuestSwiftMetadata(void) {
  if (AppBoxDiagnosticAdversarysBase == 0) {
    NSLog(@"APPBOX_SWIFT_METADATA registration_failed reason=runtime_base");
    return NO;
  }
  AppBoxSwiftRegistrationContext context = {
    .registerProtocols = (AppBoxSwiftRegisterRangeFunction)dlsym(
        RTLD_DEFAULT, "swift_registerProtocols"),
    .registerConformances = (AppBoxSwiftRegisterRangeFunction)dlsym(
        RTLD_DEFAULT, "swift_registerProtocolConformances"),
    .registerTypes = (AppBoxSwiftRegisterRangeFunction)dlsym(
        RTLD_DEFAULT, "swift_registerTypeMetadataRecords"),
  };
  if (context.registerConformances == NULL) {
    NSLog(@"APPBOX_SWIFT_METADATA registration_failed reason=runtime_api");
    return NO;
  }

  uintptr_t allowedStart = AppBoxDiagnosticAdversarysBase + 0x05000000;
  uintptr_t allowedEnd = AppBoxDiagnosticAdversarysBase + 0x10000000;
  uintptr_t page =
      (allowedStart + vm_page_size - 1) & ~(uintptr_t)(vm_page_size - 1);
  for (; page + sizeof(struct mach_header_64) <= allowedEnd;
       page += vm_page_size) {
    const struct mach_header_64 *header =
        (const struct mach_header_64 *)page;
    if (header->magic == MH_MAGIC_64) {
      AppBoxRegisterSwiftMetadataForImage(
          page, allowedStart, allowedEnd, &context);
    }
  }
  NSLog(@"APPBOX_SWIFT_METADATA registered images=%lu protocols=%lu "
        "conformances=%lu types=%lu",
        (unsigned long)context.images,
        (unsigned long)context.protocolSections,
        (unsigned long)context.conformanceSections,
        (unsigned long)context.typeSections);
  return context.conformanceSections > 0;
}

static const struct mach_header_64 *AppBoxMappedChungongMainImageHeader(void) {
  if (AppBoxDiagnosticAdversarysBase == 0) {
    return NULL;
  }
  uintptr_t allowedStart = AppBoxDiagnosticAdversarysBase + 0x05000000;
  uintptr_t allowedEnd = AppBoxDiagnosticAdversarysBase + 0x10000000;
  uintptr_t page =
      (allowedStart + vm_page_size - 1) & ~(uintptr_t)(vm_page_size - 1);
  for (; page + sizeof(struct mach_header_64) <= allowedEnd;
       page += vm_page_size) {
    const struct mach_header_64 *header =
        (const struct mach_header_64 *)page;
    if (header->magic == MH_MAGIC_64 && header->filetype == MH_EXECUTE) {
      return header;
    }
  }
  return NULL;
}

static const struct mach_header_64 *AppBoxMappedGuestDylibHeaderWithSuffix(
    const char *suffix) {
  if (AppBoxDiagnosticAdversarysBase == 0 || suffix == NULL) {
    return NULL;
  }
  uintptr_t allowedStart = AppBoxDiagnosticAdversarysBase + 0x05000000;
  uintptr_t allowedEnd = AppBoxDiagnosticAdversarysBase + 0x10000000;
  uintptr_t page =
      (allowedStart + vm_page_size - 1) & ~(uintptr_t)(vm_page_size - 1);
  size_t suffixLength = strlen(suffix);
  for (; page + sizeof(struct mach_header_64) <= allowedEnd;
       page += vm_page_size) {
    const struct mach_header_64 *header =
        (const struct mach_header_64 *)page;
    if (header->magic != MH_MAGIC_64 || header->filetype != MH_DYLIB ||
        header->ncmds == 0 || header->ncmds > 1024 ||
        header->sizeofcmds > 0x20000) {
      continue;
    }
    const uint8_t *cursor = (const uint8_t *)(header + 1);
    const uint8_t *commandsEnd = cursor + header->sizeofcmds;
    for (uint32_t index = 0; index < header->ncmds; index++) {
      if (cursor + sizeof(struct load_command) > commandsEnd) {
        break;
      }
      const struct load_command *command =
          (const struct load_command *)cursor;
      if (command->cmdsize < sizeof(struct load_command) ||
          cursor + command->cmdsize > commandsEnd) {
        break;
      }
      if (command->cmd == LC_ID_DYLIB &&
          command->cmdsize >= sizeof(struct dylib_command)) {
        const struct dylib_command *dylib =
            (const struct dylib_command *)command;
        uint32_t nameOffset = dylib->dylib.name.offset;
        if (nameOffset < command->cmdsize) {
          const char *name = (const char *)cursor + nameOffset;
          size_t maximumLength = command->cmdsize - nameOffset;
          size_t length = strnlen(name, maximumLength);
          if (length >= suffixLength && length < maximumLength &&
              memcmp(name + length - suffixLength, suffix, suffixLength) == 0) {
            return header;
          }
        }
      }
      cursor += command->cmdsize;
    }
  }
  return NULL;
}

static BOOL AppBoxPrewarmChungongKingfisherWrapperMetadata(void) {
  const struct mach_header_64 *header =
      AppBoxMappedGuestDylibHeaderWithSuffix(
          "Kingfisher.framework/Kingfisher");
  if (header == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_metadata_failed "
          "reason=image_missing");
    return NO;
  }

  // Kingfisher.Wrapper<UIImageView>'s descriptor is at VM 0xb6880 and its
  // metadata-accessor relative field is twelve bytes into that descriptor.
  // Seal first asks for this specialization from the translated tab
  // controller's viewDidLoad.  Letting native Swift instantiate it there
  // calls a mapped Kingfisher completion thunk while adversarys already owns
  // an active guest frame.  Prime the identical cache key before entering
  // viewDidLoad so the translated accessor takes Swift's cached fast path.
  // Call swift_getGenericMetadata directly: entering the translated accessor
  // first would itself create an adversarys frame and merely move the same
  // non-reentrant callback one level earlier.
  uintptr_t fieldAddress = (uintptr_t)header + 0x000B688C;
  int32_t relativeTarget = 0;
  memcpy(&relativeTarget, (const void *)fieldAddress, sizeof(relativeTarget));
  uintptr_t targetAddress = fieldAddress + (intptr_t)relativeTarget;
  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  uintptr_t nativeTarget =
      (uintptr_t)(void *)&AppBoxChungongKingfisherWrapperMetadataAccessor;
  BOOL targetIsRuntimeThunk =
      targetAddress >= runtimeStart &&
      targetAddress < runtimeStart + 0x05000000;
  if (!targetIsRuntimeThunk && targetAddress != nativeTarget) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_metadata_failed "
          "reason=target_invalid field=%p target=%p",
          (void *)fieldAddress, (void *)targetAddress);
    return NO;
  }

  typedef const void *(*SwiftGetObjCClassMetadataFunction)(Class);
  SwiftGetObjCClassMetadataFunction getObjCClassMetadata =
      (SwiftGetObjCClassMetadataFunction)dlsym(
          RTLD_DEFAULT, "swift_getObjCClassMetadata");
  if (getObjCClassMetadata == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_metadata_failed "
          "reason=objc_metadata_api");
    return NO;
  }
  const void *imageViewMetadata =
      getObjCClassMetadata([UIImageView class]);
  if (imageViewMetadata == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_metadata_failed "
          "reason=image_view_metadata");
    return NO;
  }

  AppBoxSwiftGetGenericMetadataFunction getGenericMetadata =
      (AppBoxSwiftGetGenericMetadataFunction)dlsym(
          RTLD_DEFAULT, "swift_getGenericMetadata");
  if (getGenericMetadata == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_metadata_failed "
          "reason=generic_metadata_api");
    return NO;
  }
  const void *arguments[3] = {imageViewMetadata, NULL, NULL};
  const void *descriptor = (const void *)((uintptr_t)header + 0x000B6880);
  NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_metadata_prewarm_start "
        "field=%p target=%p descriptor=%p argument=%p",
        (void *)fieldAddress, (void *)targetAddress, descriptor,
        imageViewMetadata);
  AppBoxChungongMetadataResponse response =
      getGenericMetadata(0xFF, arguments, descriptor);
  if (response.value == 0) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_metadata_failed "
          "reason=nil_result");
    return NO;
  }
  NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_metadata_prewarm_done "
        "value=%p state=%p",
        (void *)response.value, (void *)response.state);
  return YES;
}

enum {
  AppBoxChungongKingfisherWrapperMetadataStubOffset = 0x0088BB28,
  AppBoxChungongKingfisherImageResourceMetadataStubOffset = 0x0088BB40,
  AppBoxChungongKingfisherDownloadTaskMetadataStubOffset = 0x0088BB58,
  AppBoxChungongKingfisherWrapperMetadataSlotOffset = 0x062E3FC0,
  AppBoxChungongKingfisherImageResourceMetadataSlotOffset = 0x062E3FC8,
  AppBoxChungongKingfisherDownloadTaskMetadataSlotOffset = 0x062E3FD0,
};

__attribute__((noreturn, used, visibility("default")))
void AppBoxEnterGuestMainLoop(void) {
  NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_main_loop_enter");
  for (;;) {
    CFRunLoopRun();
  }
}

static BOOL AppBoxPopulateChungongCachedMetadataStub(
    uintptr_t stubOffset, uintptr_t slotOffset, uintptr_t metadata,
    const char *name, uintptr_t *targetOut) {
  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  if (runtimeStart == 0 || metadata == 0) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT cached_metadata_stub_failed "
          "name=%s reason=missing_value runtime=%p metadata=%p",
          name, (void *)runtimeStart, (void *)metadata);
    return NO;
  }
  uintptr_t target = runtimeStart + stubOffset;
  uintptr_t slot = runtimeStart + slotOffset;
  memcpy((void *)slot, &metadata, sizeof(metadata));
  uintptr_t installed = 0;
  memcpy(&installed, (const void *)slot, sizeof(installed));
  if (installed != metadata) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT cached_metadata_stub_failed "
          "name=%s reason=slot_verify slot=%p expected=%p actual=%p",
          name, (void *)slot, (void *)metadata, (void *)installed);
    return NO;
  }
  if (targetOut != NULL) {
    *targetOut = target;
  }
  NSLog(@"APPBOX_CHUNGONG_COMPAT cached_metadata_stub_ready "
        "name=%s target=%p slot=%p metadata=%p",
        name, (void *)target, (void *)slot, (void *)metadata);
  return YES;
}

static BOOL AppBoxInstallChungongKingfisherWrapperMetadataCompatibility(
    void) {
  const struct mach_header_64 *header =
      AppBoxMappedGuestDylibHeaderWithSuffix(
          "Kingfisher.framework/Kingfisher");
  if (header == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_wrapper_failed "
          "reason=image_missing");
    return NO;
  }

  uintptr_t fieldAddress = (uintptr_t)header + 0x000B688C;
  int32_t relativeTarget = 0;
  memcpy(&relativeTarget, (const void *)fieldAddress, sizeof(relativeTarget));
  uintptr_t oldTarget = fieldAddress + (intptr_t)relativeTarget;
  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  if (oldTarget < runtimeStart || oldTarget >= runtimeStart + 0x05000000) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_wrapper_failed "
          "reason=target_invalid field=%p target=%p",
          (void *)fieldAddress, (void *)oldTarget);
    return NO;
  }

  AppBoxChungongKingfisherBase = (uintptr_t)header;
  AppBoxChungongKingfisherWrapperDescriptor =
      (const void *)((uintptr_t)header + 0x000B6880);
  AppBoxChungongSwiftGetGenericMetadata =
      (AppBoxSwiftGetGenericMetadataFunction)dlsym(
          RTLD_DEFAULT, "swift_getGenericMetadata");
  if (AppBoxChungongSwiftGetGenericMetadata == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_wrapper_failed "
          "reason=generic_metadata_api");
    return NO;
  }

  typedef const void *(*SwiftGetObjCClassMetadataFunction)(Class);
  SwiftGetObjCClassMetadataFunction getObjCClassMetadata =
      (SwiftGetObjCClassMetadataFunction)dlsym(
          RTLD_DEFAULT, "swift_getObjCClassMetadata");
  const void *imageViewMetadata = getObjCClassMetadata == NULL
      ? NULL
      : getObjCClassMetadata([UIImageView class]);
  if (imageViewMetadata == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_wrapper_failed "
          "reason=image_view_metadata");
    return NO;
  }
  const void *arguments[3] = {imageViewMetadata, NULL, NULL};
  AppBoxChungongMetadataResponse response =
      AppBoxChungongSwiftGetGenericMetadata(
          0xFF, arguments, AppBoxChungongKingfisherWrapperDescriptor);
  uintptr_t nativeTarget = 0;
  if (response.value == 0 ||
      !AppBoxPopulateChungongCachedMetadataStub(
          AppBoxChungongKingfisherWrapperMetadataStubOffset,
          AppBoxChungongKingfisherWrapperMetadataSlotOffset,
          response.value, "kingfisher_wrapper", &nativeTarget)) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_wrapper_failed "
          "reason=metadata_prewarm value=%p state=%p",
          (void *)response.value, (void *)response.state);
    return NO;
  }
  intptr_t nativeDisplacement =
      (intptr_t)nativeTarget - (intptr_t)fieldAddress;
  if (nativeDisplacement < INT32_MIN || nativeDisplacement > INT32_MAX) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_wrapper_failed "
          "reason=native_target_out_of_range target=%p",
          (void *)nativeTarget);
    return NO;
  }

  vm_address_t pageAddress = fieldAddress & ~(vm_address_t)(vm_page_size - 1);
  kern_return_t protection =
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ | VM_PROT_WRITE);
  if (protection != KERN_SUCCESS) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_wrapper_failed "
          "reason=protect_write code=%d",
          protection);
    return NO;
  }
  int32_t replacement = (int32_t)nativeDisplacement;
  memcpy((void *)fieldAddress, &replacement, sizeof(replacement));
  vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE, VM_PROT_READ);
  NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_wrapper_patched "
        "field=%p old=%p native=%p descriptor=%p metadata=%p",
        (void *)fieldAddress, (void *)oldTarget, (void *)nativeTarget,
        AppBoxChungongKingfisherWrapperDescriptor, (void *)response.value);
  return YES;
}

static BOOL AppBoxInstallChungongKingfisherImageResourceMetadataCompatibility(
    void) {
  const struct mach_header_64 *header =
      AppBoxMappedGuestDylibHeaderWithSuffix(
          "Kingfisher.framework/Kingfisher");
  if (header == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_image_resource_failed "
          "reason=image_missing");
    return NO;
  }

  // Kingfisher.KF.ImageResource's nominal descriptor is at 0xb701c. Its
  // metadata accessor at 0x95a34 is otherwise reached through an adversarys
  // thunk while Seal's viewDidLoad already owns a guest frame.
  uintptr_t fieldAddress = (uintptr_t)header + 0x000B7028;
  int32_t relativeTarget = 0;
  memcpy(&relativeTarget, (const void *)fieldAddress, sizeof(relativeTarget));
  uintptr_t oldTarget = fieldAddress + (intptr_t)relativeTarget;
  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  if (oldTarget < runtimeStart || oldTarget >= runtimeStart + 0x05000000) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_image_resource_failed "
          "reason=target_invalid field=%p target=%p",
          (void *)fieldAddress, (void *)oldTarget);
    return NO;
  }

  AppBoxChungongKingfisherBase = (uintptr_t)header;
  AppBoxChungongKingfisherImageResourceDescriptor =
      (const void *)((uintptr_t)header + 0x000B701C);
  AppBoxChungongSwiftGetSingletonMetadata =
      (AppBoxSwiftGetSingletonMetadataFunction)dlsym(
          RTLD_DEFAULT, "swift_getSingletonMetadata");
  if (AppBoxChungongSwiftGetSingletonMetadata == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_image_resource_failed "
          "reason=singleton_metadata_api");
    return NO;
  }

  AppBoxChungongMetadataResponse response =
      AppBoxChungongSwiftGetSingletonMetadata(
          0xFF, AppBoxChungongKingfisherImageResourceDescriptor);
  uintptr_t nativeTarget = 0;
  if (response.value == 0 ||
      !AppBoxPopulateChungongCachedMetadataStub(
          AppBoxChungongKingfisherImageResourceMetadataStubOffset,
          AppBoxChungongKingfisherImageResourceMetadataSlotOffset,
          response.value, "kingfisher_image_resource", &nativeTarget)) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_image_resource_failed "
          "reason=metadata_prewarm value=%p state=%p",
          (void *)response.value, (void *)response.state);
    return NO;
  }
  intptr_t nativeDisplacement =
      (intptr_t)nativeTarget - (intptr_t)fieldAddress;
  if (nativeDisplacement < INT32_MIN || nativeDisplacement > INT32_MAX) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_image_resource_failed "
          "reason=native_target_out_of_range target=%p",
          (void *)nativeTarget);
    return NO;
  }

  vm_address_t pageAddress = fieldAddress & ~(vm_address_t)(vm_page_size - 1);
  kern_return_t protection =
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ | VM_PROT_WRITE);
  if (protection != KERN_SUCCESS) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_image_resource_failed "
          "reason=protect_write code=%d",
          protection);
    return NO;
  }
  int32_t replacement = (int32_t)nativeDisplacement;
  memcpy((void *)fieldAddress, &replacement, sizeof(replacement));
  vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE, VM_PROT_READ);
  NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_image_resource_patched "
        "field=%p old=%p native=%p descriptor=%p metadata=%p",
        (void *)fieldAddress, (void *)oldTarget, (void *)nativeTarget,
        AppBoxChungongKingfisherImageResourceDescriptor,
        (void *)response.value);
  return YES;
}

static BOOL AppBoxInstallChungongKingfisherDownloadTaskMetadataCompatibility(
    void) {
  const struct mach_header_64 *header =
      AppBoxMappedGuestDylibHeaderWithSuffix(
          "Kingfisher.framework/Kingfisher");
  if (header == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_download_task_failed "
          "reason=image_missing");
    return NO;
  }

  // DownloadTask's nominal type descriptor is at VM 0xb5ce0. Its direct
  // metadata accessor at 0x41b30 only returns header+0xc8f68 and state zero.
  // Swift's mangled-type resolver reaches this field from inside translated
  // viewDidLoad; retaining the loader's guest thunk would recursively enter
  // adversarys. Point it at the equivalent native accessor instead.
  uintptr_t fieldAddress = (uintptr_t)header + 0x000B5CEC;
  int32_t relativeTarget = 0;
  memcpy(&relativeTarget, (const void *)fieldAddress, sizeof(relativeTarget));
  uintptr_t oldTarget = fieldAddress + (intptr_t)relativeTarget;
  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  if (oldTarget < runtimeStart || oldTarget >= runtimeStart + 0x05000000) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_download_task_failed "
          "reason=target_invalid field=%p target=%p",
          (void *)fieldAddress, (void *)oldTarget);
    return NO;
  }

  AppBoxChungongKingfisherBase = (uintptr_t)header;
  uintptr_t metadata = AppBoxChungongKingfisherBase + 0x000C8F68;
  uintptr_t nativeTarget = 0;
  if (!AppBoxPopulateChungongCachedMetadataStub(
          AppBoxChungongKingfisherDownloadTaskMetadataStubOffset,
          AppBoxChungongKingfisherDownloadTaskMetadataSlotOffset,
          metadata, "kingfisher_download_task", &nativeTarget)) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_download_task_failed "
          "reason=metadata_stub");
    return NO;
  }
  intptr_t nativeDisplacement =
      (intptr_t)nativeTarget - (intptr_t)fieldAddress;
  if (nativeDisplacement < INT32_MIN || nativeDisplacement > INT32_MAX) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_download_task_failed "
          "reason=native_target_out_of_range target=%p",
          (void *)nativeTarget);
    return NO;
  }

  vm_address_t pageAddress = fieldAddress & ~(vm_address_t)(vm_page_size - 1);
  kern_return_t protection =
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ | VM_PROT_WRITE);
  if (protection != KERN_SUCCESS) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_download_task_failed "
          "reason=protect_write code=%d",
          protection);
    return NO;
  }
  int32_t replacement = (int32_t)nativeDisplacement;
  memcpy((void *)fieldAddress, &replacement, sizeof(replacement));
  vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE, VM_PROT_READ);
  NSLog(@"APPBOX_CHUNGONG_COMPAT kingfisher_download_task_patched "
        "field=%p old=%p native=%p metadata=%p",
        (void *)fieldAddress, (void *)oldTarget, (void *)nativeTarget,
        (void *)metadata);
  return YES;
}

static Class AppBoxMappedChungongFullScreenControllerClass(void) {
  const struct mach_header_64 *header =
      AppBoxMappedChungongMainImageHeader();
  if (header == NULL) {
    return Nil;
  }
  // Seal's authenticated __objc_classlist places
  // _TtC4Seal22CLFullScreenController at VM 0x1010c3850. The translated
  // main image is mapped at its original 0x100000000-relative layout.
  return (__bridge Class)((void *)((uintptr_t)header + 0x010C3850));
}

static BOOL AppBoxPrewarmChungongUIViewControllerMetadata(void) {
  const struct mach_header_64 *header =
      AppBoxMappedChungongMainImageHeader();
  if (header == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT metadata_prewarm_failed reason=image_missing");
    return NO;
  }

  // Seal's __swift5_typeref record at 0xEA587C is a relative reference to
  // the lazy UIViewController metadata accessor at guest PC 0xC7AC. The
  // NIVM loader rewrites that relative field to its native callback thunk.
  // Resolving it once while no guest frame is active prevents Swift from
  // entering the non-reentrant interpreter during AppDelegate startup.
  uintptr_t fieldAddress = (uintptr_t)header + 0x00EA587C;
  int32_t relativeTarget = 0;
  memcpy(&relativeTarget, (const void *)fieldAddress, sizeof(relativeTarget));
  uintptr_t targetAddress = fieldAddress + (intptr_t)relativeTarget;
  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  uintptr_t runtimeEnd = runtimeStart + 0x05000000;
  if (targetAddress < runtimeStart || targetAddress >= runtimeEnd) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT metadata_prewarm_failed "
          "reason=target_invalid field=%p target=%p",
          (void *)fieldAddress, (void *)targetAddress);
    return NO;
  }

  uintptr_t (*accessor)(uintptr_t, uintptr_t, uintptr_t) =
      (uintptr_t(*)(uintptr_t, uintptr_t, uintptr_t))(void *)targetAddress;
  NSLog(@"APPBOX_CHUNGONG_COMPAT metadata_prewarm_start field=%p target=%p",
        (void *)fieldAddress, (void *)targetAddress);
  uintptr_t value = accessor(0, 0, 0);
  if (value == 0) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT metadata_prewarm_failed reason=nil_result");
    return NO;
  }

  uintptr_t cachedReturnStub = runtimeStart + 0x0088B7C0;
  intptr_t nativeDisplacement =
      (intptr_t)cachedReturnStub - (intptr_t)fieldAddress;
  if (nativeDisplacement < INT32_MIN || nativeDisplacement > INT32_MAX) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT metadata_prewarm_failed "
          "reason=native_target_out_of_range target=%p",
          (void *)cachedReturnStub);
    return NO;
  }
  vm_address_t pageAddress = fieldAddress & ~(vm_address_t)(vm_page_size - 1);
  kern_return_t protection =
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ | VM_PROT_WRITE);
  if (protection != KERN_SUCCESS) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT metadata_prewarm_failed "
          "reason=protect_write code=%d",
          protection);
    return NO;
  }
  int32_t replacement = (int32_t)nativeDisplacement;
  memcpy((void *)fieldAddress, &replacement, sizeof(replacement));
  vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE, VM_PROT_READ);
  NSLog(@"APPBOX_CHUNGONG_COMPAT metadata_prewarm_done value=%p native=%p",
        (void *)value, (void *)cachedReturnStub);
  return YES;
}

static BOOL AppBoxInstallChungongObjectMapperCompatibility(void) {
  const struct mach_header_64 *header =
      AppBoxMappedGuestDylibHeaderWithSuffix(
          "ObjectMapper.framework/ObjectMapper");
  if (header == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_failed reason=image_missing");
    return NO;
  }
  // ObjectMapper __TEXT,__const+0x28f14 points to
  // Mapper.__deallocating_deinit (guest PC 0x14f98). The NIVM loader rewrites
  // it to an adversarys callback thunk, which is unsafe while Seal's guest
  // frame is active during didFinishLaunching.
  uintptr_t fieldAddress = (uintptr_t)header + 0x00028F14;
  int32_t relativeTarget = 0;
  memcpy(&relativeTarget, (const void *)fieldAddress, sizeof(relativeTarget));
  uintptr_t targetAddress = fieldAddress + (intptr_t)relativeTarget;
  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  if (targetAddress < runtimeStart ||
      targetAddress >= runtimeStart + 0x05000000) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_failed "
          "reason=target_invalid field=%p target=%p",
          (void *)fieldAddress, (void *)targetAddress);
    return NO;
  }
  uintptr_t nativeStub = runtimeStart + 0x0088B7CC;
  intptr_t displacement = (intptr_t)nativeStub - (intptr_t)fieldAddress;
  if (displacement < INT32_MIN || displacement > INT32_MAX) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_failed "
          "reason=native_target_out_of_range target=%p",
          (void *)nativeStub);
    return NO;
  }
  vm_address_t pageAddress = fieldAddress & ~(vm_address_t)(vm_page_size - 1);
  kern_return_t protection =
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ | VM_PROT_WRITE);
  if (protection != KERN_SUCCESS) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_failed "
          "reason=protect_write code=%d",
          protection);
    return NO;
  }
  int32_t replacement = (int32_t)displacement;
  memcpy((void *)fieldAddress, &replacement, sizeof(replacement));
  // CodableTransform.__deallocating_deinit (guest PC 0x4694) is referenced
  // by two relative metadata fields on the same __DATA_CONST page.
  uintptr_t codableFields[] = {
      (uintptr_t)header + 0x000289B4,
      (uintptr_t)header + 0x00028C34,
  };
  uintptr_t codableOldTarget = 0;
  for (NSUInteger index = 0;
       index < sizeof(codableFields) / sizeof(codableFields[0]); index++) {
    int32_t oldRelative = 0;
    memcpy(&oldRelative, (const void *)codableFields[index],
           sizeof(oldRelative));
    uintptr_t oldTarget = codableFields[index] + (intptr_t)oldRelative;
    if (oldTarget < runtimeStart ||
        oldTarget >= runtimeStart + 0x05000000) {
      NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_failed "
            "reason=codable_target_invalid field=%p target=%p",
            (void *)codableFields[index], (void *)oldTarget);
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ);
      return NO;
    }
    intptr_t codableDisplacement =
        (intptr_t)nativeStub - (intptr_t)codableFields[index];
    int32_t codableReplacement = (int32_t)codableDisplacement;
    memcpy((void *)codableFields[index], &codableReplacement,
           sizeof(codableReplacement));
    codableOldTarget = oldTarget;
  }
  vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE, VM_PROT_READ);

  // Map.__deallocating_deinit (guest PC 0xeda0) is stored as an authenticated
  // absolute callback in ObjectMapper __DATA+0x2d3c0. The loader materializes
  // it as another adversarys thunk rather than a signed relative field.
  uintptr_t mapDeallocField = (uintptr_t)header + 0x0002D3C0;
  uintptr_t mapDeallocTarget = 0;
  memcpy(&mapDeallocTarget, (const void *)mapDeallocField,
         sizeof(mapDeallocTarget));
  if (mapDeallocTarget < runtimeStart ||
      mapDeallocTarget >= runtimeStart + 0x05000000) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_failed "
          "reason=map_target_invalid field=%p target=%p",
          (void *)mapDeallocField, (void *)mapDeallocTarget);
    return NO;
  }
  vm_address_t mapPage =
      mapDeallocField & ~(vm_address_t)(vm_page_size - 1);
  kern_return_t mapProtection =
      vm_protect(mach_task_self(), mapPage, vm_page_size, FALSE,
                 VM_PROT_READ | VM_PROT_WRITE);
  if (mapProtection != KERN_SUCCESS) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_failed "
          "reason=protect_map code=%d",
          mapProtection);
    return NO;
  }
  memcpy((void *)mapDeallocField, &nativeStub, sizeof(nativeStub));
  vm_protect(mach_task_self(), mapPage, vm_page_size, FALSE,
             VM_PROT_READ | VM_PROT_WRITE);
  NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_patched "
        "mapper_field=%p mapper_old=%p codable_old=%p map_field=%p "
        "map_old=%p native=%p",
        (void *)fieldAddress, (void *)targetAddress,
        (void *)codableOldTarget, (void *)mapDeallocField,
        (void *)mapDeallocTarget, (void *)nativeStub);
  return YES;
}

static BOOL AppBoxInstallChungongObjectMapperMetadataCompatibility(void) {
  const struct mach_header_64 *header =
      AppBoxMappedGuestDylibHeaderWithSuffix(
          "ObjectMapper.framework/ObjectMapper");
  if (header == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_metadata_failed "
          "reason=image_missing");
    return NO;
  }

  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  uintptr_t allocationStub = runtimeStart + 0x0088B7E4;
  uintptr_t enumCompletionStub = runtimeStart + 0x0088B824;
  uintptr_t mapperCompletionStub = runtimeStart + 0x0088B874;
  uintptr_t allocationFields[] = {
      (uintptr_t)header + 0x000289A8,
      (uintptr_t)header + 0x00028C28,
      (uintptr_t)header + 0x00028F08,
      (uintptr_t)header + 0x00029058,
  };
  uintptr_t enumCompletionField = (uintptr_t)header + 0x00028C2C;
  uintptr_t mapperCompletionField = (uintptr_t)header + 0x00028F0C;

  vm_address_t pageAddress =
      allocationFields[0] & ~(vm_address_t)(vm_page_size - 1);
  kern_return_t protection =
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ | VM_PROT_WRITE);
  if (protection != KERN_SUCCESS) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_metadata_failed "
          "reason=protect_write code=%d",
          protection);
    return NO;
  }

  uintptr_t oldAllocation = 0;
  for (NSUInteger index = 0;
       index < sizeof(allocationFields) / sizeof(allocationFields[0]);
       index++) {
    int32_t oldRelative = 0;
    memcpy(&oldRelative, (const void *)allocationFields[index],
           sizeof(oldRelative));
    uintptr_t oldTarget =
        allocationFields[index] + (intptr_t)oldRelative;
    if (oldTarget < runtimeStart ||
        oldTarget >= runtimeStart + 0x05000000) {
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ);
      NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_metadata_failed "
            "reason=allocation_target_invalid field=%p target=%p",
            (void *)allocationFields[index], (void *)oldTarget);
      return NO;
    }
    intptr_t displacement =
        (intptr_t)allocationStub - (intptr_t)allocationFields[index];
    int32_t replacement = (int32_t)displacement;
    memcpy((void *)allocationFields[index], &replacement,
           sizeof(replacement));
    oldAllocation = oldTarget;
  }

  uintptr_t completionFields[] = {
      enumCompletionField,
      mapperCompletionField,
  };
  uintptr_t completionStubs[] = {
      enumCompletionStub,
      mapperCompletionStub,
  };
  uintptr_t oldCompletions[2] = {0};
  for (NSUInteger index = 0; index < 2; index++) {
    int32_t oldRelative = 0;
    memcpy(&oldRelative, (const void *)completionFields[index],
           sizeof(oldRelative));
    uintptr_t oldTarget =
        completionFields[index] + (intptr_t)oldRelative;
    if (oldTarget < runtimeStart ||
        oldTarget >= runtimeStart + 0x05000000) {
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ);
      NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_metadata_failed "
            "reason=completion_target_invalid field=%p target=%p",
            (void *)completionFields[index], (void *)oldTarget);
      return NO;
    }
    intptr_t displacement =
        (intptr_t)completionStubs[index] -
        (intptr_t)completionFields[index];
    int32_t replacement = (int32_t)displacement;
    memcpy((void *)completionFields[index], &replacement,
           sizeof(replacement));
    oldCompletions[index] = oldTarget;
  }
  vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE, VM_PROT_READ);
  NSLog(@"APPBOX_CHUNGONG_COMPAT objectmapper_metadata_patched "
        "allocation_old=%p allocation_native=%p enum_old=%p enum_native=%p "
        "mapper_old=%p mapper_native=%p",
        (void *)oldAllocation, (void *)allocationStub,
        (void *)oldCompletions[0], (void *)enumCompletionStub,
        (void *)oldCompletions[1], (void *)mapperCompletionStub);
  return YES;
}

static BOOL AppBoxInstallChungongAppearanceEnumCompatibility(void) {
  const struct mach_header_64 *header =
      AppBoxMappedChungongMainImageHeader();
  if (header == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT appearance_enum_failed "
          "reason=image_missing");
    return NO;
  }
  // Seal __const+0xd6d244 points to the String-to-appearance enum callback at
  // guest PC 0x239a6c. Native Swift calls it while didFinishLaunching still
  // owns the translated frame, so redirect it to a signed native byte writer.
  uintptr_t fieldAddress = (uintptr_t)header + 0x00D6D244;
  int32_t oldRelative = 0;
  memcpy(&oldRelative, (const void *)fieldAddress, sizeof(oldRelative));
  uintptr_t oldTarget = fieldAddress + (intptr_t)oldRelative;
  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  if (oldTarget < runtimeStart || oldTarget >= runtimeStart + 0x05000000) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT appearance_enum_failed "
          "reason=target_invalid field=%p target=%p",
          (void *)fieldAddress, (void *)oldTarget);
    return NO;
  }
  uintptr_t nativeStub = runtimeStart + 0x0088B7D0;
  intptr_t displacement = (intptr_t)nativeStub - (intptr_t)fieldAddress;
  if (displacement < INT32_MIN || displacement > INT32_MAX) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT appearance_enum_failed "
          "reason=native_target_out_of_range target=%p",
          (void *)nativeStub);
    return NO;
  }
  vm_address_t pageAddress = fieldAddress & ~(vm_address_t)(vm_page_size - 1);
  kern_return_t protection =
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ | VM_PROT_WRITE);
  if (protection != KERN_SUCCESS) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT appearance_enum_failed "
          "reason=protect_write code=%d",
          protection);
    return NO;
  }
  int32_t replacement = (int32_t)displacement;
  memcpy((void *)fieldAddress, &replacement, sizeof(replacement));
  vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE, VM_PROT_READ);
  NSLog(@"APPBOX_CHUNGONG_COMPAT appearance_enum_patched "
        "field=%p old=%p native=%p",
        (void *)fieldAddress, (void *)oldTarget, (void *)nativeStub);
  return YES;
}

static BOOL AppBoxPrewarmChungongModelWitness(void) {
  const struct mach_header_64 *header =
      AppBoxMappedChungongMainImageHeader();
  if (header == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT model_witness_prewarm_failed "
          "reason=image_missing");
    return NO;
  }

  // Seal __swift5_proto+0xeab012 references the lazy witness accessor at
  // guest PC 0x239e78. During didFinishLaunching, Swift asks this accessor
  // to instantiate several ObjectMapper generic metadata records. Running
  // the same accessor before entering AppDelegate moves those native-to-guest
  // callbacks out of the long-lived translated launch frame.
  uintptr_t fieldAddress = (uintptr_t)header + 0x00EAB012;
  int32_t relativeTarget = 0;
  memcpy(&relativeTarget, (const void *)fieldAddress, sizeof(relativeTarget));
  uintptr_t targetAddress = fieldAddress + (intptr_t)relativeTarget;
  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  if (targetAddress < runtimeStart ||
      targetAddress >= runtimeStart + 0x05000000) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT model_witness_prewarm_failed "
          "reason=target_invalid field=%p target=%p",
          (void *)fieldAddress, (void *)targetAddress);
    return NO;
  }

  uintptr_t (*accessor)(uintptr_t, uintptr_t, uintptr_t) =
      (uintptr_t(*)(uintptr_t, uintptr_t, uintptr_t))(void *)targetAddress;
  NSLog(@"APPBOX_CHUNGONG_COMPAT model_witness_prewarm_start "
        "field=%p target=%p",
        (void *)fieldAddress, (void *)targetAddress);
  uintptr_t value = accessor(0, 0, 0);
  if (value == 0) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT model_witness_prewarm_failed "
          "reason=nil_result");
    return NO;
  }

  uintptr_t nativeStub = runtimeStart + 0x0088B7D8;
  intptr_t displacement =
      (intptr_t)nativeStub - (intptr_t)fieldAddress;
  if (displacement < INT32_MIN || displacement > INT32_MAX) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT model_witness_prewarm_failed "
          "reason=native_target_out_of_range target=%p",
          (void *)nativeStub);
    return NO;
  }
  vm_address_t pageAddress = fieldAddress & ~(vm_address_t)(vm_page_size - 1);
  kern_return_t protection =
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ | VM_PROT_WRITE);
  if (protection != KERN_SUCCESS) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT model_witness_prewarm_failed "
          "reason=protect_write code=%d",
          protection);
    return NO;
  }
  int32_t replacement = (int32_t)displacement;
  memcpy((void *)fieldAddress, &replacement, sizeof(replacement));
  vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE, VM_PROT_READ);
  NSLog(@"APPBOX_CHUNGONG_COMPAT model_witness_prewarm_done "
        "value=%p native=%p",
        (void *)value, (void *)nativeStub);
  return YES;
}

typedef void *(*AppBoxSwiftBridgeObjectRetainFunction)(void *object);
typedef void (*AppBoxSwiftBridgeObjectReleaseFunction)(void *object);

static AppBoxSwiftBridgeObjectRetainFunction
    AppBoxChungongBridgeObjectRetain = NULL;
static AppBoxSwiftBridgeObjectReleaseFunction
    AppBoxChungongBridgeObjectRelease = NULL;

static void *AppBoxChungongModelCopyWitness(void *destination,
                                            const void *source) {
  memcpy(destination, source, 0xB1);
  const uintptr_t bridgeOffsets[] = {
      0x08, 0x18, 0x28, 0x38, 0x48, 0x58,
      0x68, 0x78, 0x88, 0x98, 0xA8,
  };
  for (NSUInteger index = 0;
       index < sizeof(bridgeOffsets) / sizeof(bridgeOffsets[0]); index++) {
    void *object = NULL;
    memcpy(&object, (const uint8_t *)destination + bridgeOffsets[index],
           sizeof(object));
    AppBoxChungongBridgeObjectRetain(object);
  }
  return destination;
}

static void AppBoxChungongModelDestroyWitness(void *value) {
  const uintptr_t bridgeOffsets[] = {
      0x08, 0x18, 0x28, 0x38, 0x48, 0x58,
      0x68, 0x78, 0x88, 0x98, 0xA8,
  };
  for (NSUInteger index = 0;
       index < sizeof(bridgeOffsets) / sizeof(bridgeOffsets[0]); index++) {
    void *object = NULL;
    memcpy(&object, (const uint8_t *)value + bridgeOffsets[index],
           sizeof(object));
    AppBoxChungongBridgeObjectRelease(object);
  }
}

static BOOL AppBoxInstallChungongModelValueWitnessCompatibility(void) {
  const struct mach_header_64 *header =
      AppBoxMappedChungongMainImageHeader();
  if (header == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT model_value_witness_failed "
          "reason=image_missing");
    return NO;
  }
  AppBoxChungongBridgeObjectRetain =
      (AppBoxSwiftBridgeObjectRetainFunction)dlsym(
          RTLD_DEFAULT, "swift_bridgeObjectRetain");
  AppBoxChungongBridgeObjectRelease =
      (AppBoxSwiftBridgeObjectReleaseFunction)dlsym(
          RTLD_DEFAULT, "swift_bridgeObjectRelease");
  if (AppBoxChungongBridgeObjectRetain == NULL ||
      AppBoxChungongBridgeObjectRelease == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT model_value_witness_failed "
          "reason=swift_runtime_symbols");
    return NO;
  }

  // Seal's value-witness table at 0xfc0b10 contains the destroy and copy
  // callbacks for a 0xb1-byte value made of eleven Swift bridge objects.
  // The implementations above are instruction-for-instruction equivalent to
  // guest PCs 0x239454 and 0x2394c4, but execute as signed host code.
  uintptr_t destroyField = (uintptr_t)header + 0x00FC0B10;
  uintptr_t copyField = (uintptr_t)header + 0x00FC0B18;
  uintptr_t oldDestroy = 0;
  uintptr_t oldCopy = 0;
  memcpy(&oldDestroy, (const void *)destroyField, sizeof(oldDestroy));
  memcpy(&oldCopy, (const void *)copyField, sizeof(oldCopy));
  uintptr_t runtimeStart = AppBoxDiagnosticAdversarysBase;
  if (oldDestroy < runtimeStart || oldDestroy >= runtimeStart + 0x05000000 ||
      oldCopy < runtimeStart || oldCopy >= runtimeStart + 0x05000000) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT model_value_witness_failed "
          "reason=target_invalid destroy=%p copy=%p",
          (void *)oldDestroy, (void *)oldCopy);
    return NO;
  }
  vm_address_t pageAddress = destroyField & ~(vm_address_t)(vm_page_size - 1);
  kern_return_t protection =
      vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE,
                 VM_PROT_READ | VM_PROT_WRITE);
  if (protection != KERN_SUCCESS) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT model_value_witness_failed "
          "reason=protect_write code=%d",
          protection);
    return NO;
  }
  uintptr_t nativeDestroy =
      (uintptr_t)(void *)&AppBoxChungongModelDestroyWitness;
  uintptr_t nativeCopy = (uintptr_t)(void *)&AppBoxChungongModelCopyWitness;
  memcpy((void *)destroyField, &nativeDestroy, sizeof(nativeDestroy));
  memcpy((void *)copyField, &nativeCopy, sizeof(nativeCopy));
  vm_protect(mach_task_self(), pageAddress, vm_page_size, FALSE, VM_PROT_READ);
  NSLog(@"APPBOX_CHUNGONG_COMPAT model_value_witness_patched "
        "destroy_old=%p destroy_native=%p copy_old=%p copy_native=%p",
        (void *)oldDestroy, (void *)nativeDestroy,
        (void *)oldCopy, (void *)nativeCopy);
  return YES;
}

static void AppBoxChungongLaunchPreparationViewDidLoad(id controller,
                                                        SEL selector) {
  (void)selector;
  NSLog(@"APPBOX_CHUNGONG_COMPAT native_launch_view_did_load_begin");

  UIViewController *viewController = (UIViewController *)controller;
  UIView *view = viewController.view;
  view.backgroundColor = UIColor.blackColor;
  if ([view viewWithTag:0x41504258] == nil) {
    UIImageView *imageView = [[UIImageView alloc] initWithFrame:view.bounds];
    imageView.tag = 0x41504258;
    imageView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    imageView.contentMode = UIViewContentModeScaleAspectFill;
    imageView.clipsToBounds = YES;
    imageView.image = [UIImage imageNamed:@"ic_welcome_m"
                                 inBundle:AppBoxGuestMainBundle
            compatibleWithTraitCollection:nil];
    [view addSubview:imageView];

    UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
    indicator.translatesAutoresizingMaskIntoConstraints = NO;
    indicator.color = UIColor.whiteColor;
    [indicator startAnimating];
    [view addSubview:indicator];
    [NSLayoutConstraint activateConstraints:@[
      [indicator.centerXAnchor constraintEqualToAnchor:view.centerXAnchor],
      [indicator.bottomAnchor constraintEqualToAnchor:view.safeAreaLayoutGuide
                                                   .bottomAnchor
                                              constant:-36.0],
    ]];
  }
  NSLog(@"APPBOX_CHUNGONG_COMPAT native_launch_view_loaded image=%d",
        [UIImage imageNamed:@"ic_welcome_m"
                   inBundle:AppBoxGuestMainBundle
          compatibleWithTraitCollection:nil] != nil);
}

static void AppBoxChungongLaunchPreparationLoadView(id controller,
                                                     SEL selector) {
  (void)selector;
  NSLog(@"APPBOX_CHUNGONG_COMPAT native_launch_load_view_begin");
  CGRect bounds = UIScreen.mainScreen.bounds;
  UIView *view = [[UIView alloc] initWithFrame:bounds];
  view.backgroundColor = UIColor.blackColor;
  ((UIViewController *)controller).view = view;
  NSLog(@"APPBOX_CHUNGONG_COMPAT native_launch_load_view_end");
}

static void AppBoxInstallChungongLaunchControllerCompatibility(void) {
  Class controllerClass =
      NSClassFromString(@"Seal.LaunchPreparationViewController");
  if (controllerClass == Nil) {
    controllerClass =
        objc_getClass("_TtC4Seal31LaunchPreparationViewController");
  }
  const char *className = controllerClass == Nil
      ? NULL
      : class_getName(controllerClass);
  if (className == NULL ||
      (strcmp(className, "Seal.LaunchPreparationViewController") != 0 &&
       strcmp(className,
              "_TtC4Seal31LaunchPreparationViewController") != 0)) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT launch_controller_missing");
    return;
  }
  SEL selector = @selector(viewDidLoad);
  Method method = class_getInstanceMethod(controllerClass, selector);
  if (method == NULL) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT launch_view_method_missing");
    return;
  }
  class_replaceMethod(
      controllerClass, selector,
      (IMP)AppBoxChungongLaunchPreparationViewDidLoad,
      method_getTypeEncoding(method));
  SEL loadViewSelector = @selector(loadView);
  Method loadViewMethod = class_getInstanceMethod(
      class_getSuperclass(controllerClass), loadViewSelector);
  if (loadViewMethod != NULL) {
    class_replaceMethod(
        controllerClass, loadViewSelector,
        (IMP)AppBoxChungongLaunchPreparationLoadView,
        method_getTypeEncoding(loadViewMethod));
  }
  NSLog(@"APPBOX_CHUNGONG_COMPAT launch_view_patched class=%s load_view=%d",
        className, loadViewMethod != NULL);
}

static void AppBoxInstallChungongUIKitCompatibility(void) {
  Class registeredClass = NSClassFromString(@"Seal.CLFullScreenController");
  if (registeredClass == Nil) {
    registeredClass = objc_getClass("_TtC4Seal22CLFullScreenController");
  }
  Class mappedClass = AppBoxMappedChungongFullScreenControllerClass();
  Class controllerClasses[] = {registeredClass, mappedClass};
  NSUInteger matched = 0;
  NSUInteger replaced = 0;
  for (NSUInteger classIndex = 0;
       classIndex < sizeof(controllerClasses) / sizeof(controllerClasses[0]);
       classIndex += 1) {
    Class controllerClass = controllerClasses[classIndex];
    if (controllerClass == Nil ||
        (classIndex > 0 && controllerClass == controllerClasses[0])) {
      continue;
    }
    const char *className = class_getName(controllerClass);
    if (className == NULL ||
        (strcmp(className, "Seal.CLFullScreenController") != 0 &&
         strcmp(className, "_TtC4Seal22CLFullScreenController") != 0)) {
      NSLog(@"APPBOX_CHUNGONG_COMPAT candidate_rejected pointer=%p name=%s",
            controllerClass, className ?: "unknown");
      continue;
    }
    Class superclass = class_getSuperclass(controllerClass);
    if (superclass == Nil) {
      continue;
    }
    matched += 1;

    // These five Swift overrides contain only an objc_msgSendSuper2
    // forwarder. UIKit can invoke them reentrantly while the translated
    // AppDelegate is still inside didFinishLaunching. Use the equivalent
    // native superclass implementations so this no-op path does not open a
    // nested interpreter.
    NSUInteger classReplaced = 0;
    for (NSString *selectorName in
         @[@"viewWillAppear:", @"viewDidAppear:",
           @"viewWillDisappear:", @"viewDidDisappear:",
           @"viewDidLayoutSubviews"]) {
      SEL selector = NSSelectorFromString(selectorName);
      Method method = class_getInstanceMethod(superclass, selector);
      if (method == NULL) {
        continue;
      }
      class_replaceMethod(controllerClass, selector,
                          method_getImplementation(method),
                          method_getTypeEncoding(method));
      classReplaced += 1;
      replaced += 1;
    }
    NSLog(@"APPBOX_CHUNGONG_COMPAT class_patched pointer=%p name=%s "
          "superclass=%@ methods=%lu",
          controllerClass, className, NSStringFromClass(superclass),
          (unsigned long)classReplaced);
  }
  if (matched == 0) {
    NSLog(@"APPBOX_CHUNGONG_COMPAT install_failed reason=controller_missing");
    return;
  }
  NSLog(@"APPBOX_CHUNGONG_COMPAT installed classes=%lu methods=%lu",
        (unsigned long)matched, (unsigned long)replaced);
  AppBoxInstallChungongLaunchControllerCompatibility();
}

static IMP AppBoxOriginalMakeKeyAndVisible = NULL;
static IMP AppBoxOriginalSetRootViewController = NULL;
static BOOL AppBoxDeferGuestWindowVisibility = NO;
static UIWindow *AppBoxDeferredGuestRootWindow = nil;
static UIViewController *AppBoxDeferredGuestRootController = nil;

static UIWindow *AppBoxCurrentForegroundWindow(UIApplication *application) {
  UIWindow *visibleWindow = nil;
  for (UIScene *scene in application.connectedScenes) {
    if (![scene isKindOfClass:UIWindowScene.class]) {
      continue;
    }
    for (UIWindow *window in ((UIWindowScene *)scene).windows) {
      if (window.isKeyWindow) {
        return window;
      }
      if (visibleWindow == nil && !window.hidden && window.alpha > 0) {
        visibleWindow = window;
      }
    }
  }
  return visibleWindow ?: application.windows.firstObject;
}

static void AppBoxGuestAwareMakeKeyAndVisible(UIWindow *window, SEL selector) {
  if (AppBoxDeferGuestWindowVisibility) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME window_visibility_deferred class=%@",
          NSStringFromClass(window.class));
    return;
  }
  if (AppBoxOriginalMakeKeyAndVisible != NULL) {
    ((void (*)(id, SEL))AppBoxOriginalMakeKeyAndVisible)(window, selector);
  }
}

static void AppBoxGuestAwareSetRootViewController(
    UIWindow *window, SEL selector, UIViewController *controller) {
  if (AppBoxDeferGuestWindowVisibility) {
    AppBoxDeferredGuestRootWindow = window;
    AppBoxDeferredGuestRootController = controller;
    NSLog(@"APPBOX_PLAYBOX_RUNTIME root_controller_deferred window=%@ root=%@",
          NSStringFromClass(window.class),
          NSStringFromClass(controller.class));
    return;
  }
  if (AppBoxOriginalSetRootViewController != NULL) {
    ((void (*)(id, SEL, id))AppBoxOriginalSetRootViewController)(
        window, selector, controller);
  }
}

static BOOL AppBoxBeginGuestWindowVisibilityDeferral(void) {
  Method visibilityMethod = class_getInstanceMethod(
      UIWindow.class, @selector(makeKeyAndVisible));
  Method rootControllerMethod = class_getInstanceMethod(
      UIWindow.class, @selector(setRootViewController:));
  if (visibilityMethod == NULL || rootControllerMethod == NULL) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME window_visibility_deferral_failed");
    return NO;
  }
  if (AppBoxOriginalMakeKeyAndVisible == NULL) {
    AppBoxOriginalMakeKeyAndVisible = method_setImplementation(
        visibilityMethod, (IMP)AppBoxGuestAwareMakeKeyAndVisible);
  }
  if (AppBoxOriginalSetRootViewController == NULL) {
    AppBoxOriginalSetRootViewController = method_setImplementation(
        rootControllerMethod, (IMP)AppBoxGuestAwareSetRootViewController);
  }
  AppBoxDeferredGuestRootWindow = nil;
  AppBoxDeferredGuestRootController = nil;
  AppBoxDeferGuestWindowVisibility = YES;
  return YES;
}

static void AppBoxEndGuestWindowVisibilityDeferral(BOOL installed,
                                                   BOOL applyImmediately) {
  if (installed) {
    AppBoxDeferGuestWindowVisibility = NO;
    if (!applyImmediately) {
      NSLog(@"APPBOX_PLAYBOX_RUNTIME root_controller_apply_deferred");
      return;
    }
    UIWindow *window = AppBoxDeferredGuestRootWindow;
    UIViewController *controller = AppBoxDeferredGuestRootController;
    AppBoxDeferredGuestRootWindow = nil;
    AppBoxDeferredGuestRootController = nil;
    if (window != nil && AppBoxOriginalSetRootViewController != NULL) {
      ((void (*)(id, SEL, id))AppBoxOriginalSetRootViewController)(
          window, @selector(setRootViewController:), controller);
      NSLog(@"APPBOX_PLAYBOX_RUNTIME root_controller_applied window=%@ root=%@",
            NSStringFromClass(window.class),
            NSStringFromClass(controller.class));
    }
  }
}

static void AppBoxApplyDeferredGuestRootControllerToWindow(
    UIWindow *destinationWindow) {
  UIWindow *guestWindow = AppBoxDeferredGuestRootWindow;
  UIViewController *controller = AppBoxDeferredGuestRootController;
  AppBoxDeferredGuestRootWindow = nil;
  AppBoxDeferredGuestRootController = nil;
  UIWindow *window = destinationWindow ?: guestWindow;
  if (window == nil || controller == nil ||
      AppBoxOriginalSetRootViewController == NULL) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME root_controller_apply_skipped guest=%@ "
          "destination=%@ root=%@",
          NSStringFromClass(guestWindow.class),
          NSStringFromClass(destinationWindow.class),
          NSStringFromClass(controller.class));
    return;
  }
  NSLog(@"APPBOX_PLAYBOX_RUNTIME root_controller_apply_begin guest=%@ "
        "destination=%@ root=%@",
        NSStringFromClass(guestWindow.class), NSStringFromClass(window.class),
        NSStringFromClass(controller.class));
  ((void (*)(id, SEL, id))AppBoxOriginalSetRootViewController)(
      window, @selector(setRootViewController:), controller);
  NSLog(@"APPBOX_PLAYBOX_RUNTIME root_controller_applied window=%@ root=%@",
        NSStringFromClass(window.class), NSStringFromClass(controller.class));
}

static UIViewController *AppBoxTakeDeferredGuestRootController(
    UIWindow **guestWindowOut) {
  UIWindow *guestWindow = AppBoxDeferredGuestRootWindow;
  UIViewController *controller = AppBoxDeferredGuestRootController;
  AppBoxDeferredGuestRootWindow = nil;
  AppBoxDeferredGuestRootController = nil;
  if (guestWindowOut != NULL) {
    *guestWindowOut = guestWindow;
  }
  return controller;
}

typedef void (*AppBoxTerminateHandlerFunction)(void);
typedef AppBoxTerminateHandlerFunction (*AppBoxSetTerminateFunction)(
    AppBoxTerminateHandlerFunction);

static void AppBoxDiagnosticTerminateHandler(void) {
  void *frames[96] = {0};
  int count = backtrace(frames, (int)(sizeof(frames) / sizeof(frames[0])));
  dprintf(STDERR_FILENO, "APPBOX_DIAGNOSTIC_TERMINATE frames=%d\n", count);
  backtrace_symbols_fd(frames, count, STDERR_FILENO);
  _exit(199);
}

static void AppBoxInstallDiagnosticTerminateHandler(void) {
  AppBoxSetTerminateFunction setTerminate =
      (AppBoxSetTerminateFunction)dlsym(RTLD_DEFAULT,
                                        "_ZSt13set_terminatePFvvE");
  if (setTerminate == NULL) {
    NSLog(@"APPBOX_DIAGNOSTIC_TERMINATE install_failed error=%s", dlerror());
    return;
  }
  setTerminate(AppBoxDiagnosticTerminateHandler);
  NSLog(@"APPBOX_DIAGNOSTIC_TERMINATE installed");
}

static BOOL AppBoxPreloadLooseGuestImages(NSString *bundlePath) {
  NSString *manifestPath =
      [bundlePath stringByAppendingPathComponent:@"AppBoxLooseImages.plist"];
  NSArray *images = [NSArray arrayWithContentsOfFile:manifestPath];
  if (images == nil) {
    return YES;
  }
  NSString *bundleRoot = bundlePath.stringByStandardizingPath;
  AppBoxLooseGuestImages = [NSMutableArray arrayWithCapacity:images.count];
  for (id candidate in images) {
    if (![candidate isKindOfClass:NSString.class] ||
        [candidate hasPrefix:@"/"]) {
      NSLog(@"APPBOX_PLAYBOX_RUNTIME loose_preload_failed reason=bad_path");
      return NO;
    }
    NSString *imagePath =
        [bundlePath stringByAppendingPathComponent:candidate];
    NSString *standardized = imagePath.stringByStandardizingPath;
    NSString *requiredPrefix = [bundleRoot stringByAppendingString:@"/"];
    if (![standardized hasPrefix:requiredPrefix] ||
        ![NSFileManager.defaultManager fileExistsAtPath:standardized] ||
        ![NSFileManager.defaultManager
            fileExistsAtPath:[standardized stringByAppendingString:@".fuel"]]) {
      NSLog(@"APPBOX_PLAYBOX_RUNTIME loose_preload_failed image=%@ "
            "reason=artifact_missing", candidate);
      return NO;
    }
    NSLog(@"APPBOX_PLAYBOX_RUNTIME loose_preload image=%@", candidate);
    void *handle =
        AppBoxAdversarysOpenLoose(standardized.fileSystemRepresentation);
    if (handle == NULL) {
      const char *error = AppBoxAdversarysError();
      NSLog(@"APPBOX_PLAYBOX_RUNTIME loose_preload_failed image=%@ error=%s",
            candidate, error == NULL ? "unknown" : error);
      return NO;
    }
    [AppBoxLooseGuestImages addObject:[NSValue valueWithPointer:handle]];
  }
  NSLog(@"APPBOX_PLAYBOX_RUNTIME loose_preload_ready count=%lu",
        (unsigned long)AppBoxLooseGuestImages.count);
  return YES;
}

static void AppBoxSampleAdversarysThreads(void);
static void AppBoxStartDiagnosticFileBurst(NSString *reason);
static void AppBoxStartDiagnosticFocusedBurst(void);

static void AppBoxStartDiagnosticBurst(NSString *reason) {
  if (![NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-result-burst"] ||
      !__sync_bool_compare_and_swap(&AppBoxDiagnosticBurstStarted, 0, 1)) {
    return;
  }
  NSLog(@"APPBOX_DIAGNOSTIC_BURST start reason=%@", reason);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    for (NSUInteger index = 0;
         index < 6000 &&
             AppBoxDiagnosticSampleCount < AppBoxDiagnosticSampleLimit;
         index += 1) {
      AppBoxSampleAdversarysThreads();
      usleep(500);
    }
    NSLog(@"APPBOX_DIAGNOSTIC_BURST end samples=%d",
          AppBoxDiagnosticSampleCount);
  });
}

static void AppBoxProbeLocalProxy(NSString *host, NSString *port) {
  NSString *hostCopy = [host copy];
  NSString *portCopy = [port copy];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_UTILITY, 0), ^{
    int descriptor = socket(AF_INET, SOCK_STREAM, 0);
    if (descriptor < 0) {
      NSLog(@"APPBOX_NATIVE_YUNCENG probe_socket_failed errno=%d", errno);
      return;
    }
    int flags = fcntl(descriptor, F_GETFL, 0);
    if (flags >= 0) {
      fcntl(descriptor, F_SETFL, flags | O_NONBLOCK);
    }
    struct sockaddr_in address = {0};
    address.sin_len = sizeof(address);
    address.sin_family = AF_INET;
    address.sin_port = htons((uint16_t)portCopy.intValue);
    int converted = inet_pton(AF_INET, hostCopy.UTF8String,
                              &address.sin_addr);
    int result = converted == 1
        ? connect(descriptor, (const struct sockaddr *)&address,
                  sizeof(address))
        : -1;
    int connectError = result == 0 ? 0 : errno;
    if (result != 0 && connectError == EINPROGRESS) {
      fd_set writeSet;
      FD_ZERO(&writeSet);
      FD_SET(descriptor, &writeSet);
      struct timeval timeout = {.tv_sec = 2, .tv_usec = 0};
      int selected = select(descriptor + 1, NULL, &writeSet, NULL, &timeout);
      if (selected > 0) {
        socklen_t errorLength = sizeof(connectError);
        getsockopt(descriptor, SOL_SOCKET, SO_ERROR, &connectError,
                   &errorLength);
      } else {
        connectError = selected == 0 ? ETIMEDOUT : errno;
      }
    }
    NSLog(@"APPBOX_NATIVE_YUNCENG probe target=%@:%@ errno=%d", hostCopy,
          portCopy, connectError);
    close(descriptor);
  });
}

typedef int (*AppBoxKiwiInitWithListenerFunction)(id, SEL, const char *, id);

static int AppBoxObservedConnect(int descriptor,
                                 const struct sockaddr *address,
                                 socklen_t addressLength) {
  static int (*systemConnect)(int, const struct sockaddr *, socklen_t);
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    systemConnect = dlsym(RTLD_NEXT, "connect");
  });
  int result = systemConnect == NULL
      ? -1
      : systemConnect(descriptor, address, addressLength);
  int savedError = result == 0 ? 0 : errno;
  if (address != NULL && address->sa_family == AF_INET &&
      [NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-observe-connect"]) {
    const struct sockaddr_in *ipv4 = (const struct sockaddr_in *)address;
    char target[INET_ADDRSTRLEN] = {0};
    inet_ntop(AF_INET, &ipv4->sin_addr, target, sizeof(target));
    Dl_info callerInfo = {0};
    const void *caller = __builtin_return_address(0);
    dladdr(caller, &callerInfo);
    NSString *callerImage = callerInfo.dli_fname == NULL
        ? @"unknown"
        : [NSString stringWithUTF8String:callerInfo.dli_fname]
              .lastPathComponent;
    NSLog(@"APPBOX_CONNECT target=%s:%u result=%d errno=%d caller=%@ offset=%#lx",
          target, ntohs(ipv4->sin_port), result, savedError, callerImage,
          callerInfo.dli_fbase == NULL
              ? 0UL
              : (unsigned long)((uintptr_t)caller -
                                (uintptr_t)callerInfo.dli_fbase));
  }
  errno = savedError;
  return result;
}

static int AppBoxObservedKill(pid_t process, int signalNumber) {
  static int (*systemKill)(pid_t, int);
  static dispatch_once_t onceToken;
  dispatch_once(&onceToken, ^{
    systemKill = dlsym(RTLD_NEXT, "kill");
  });
  void *frames[48] = {0};
  int count = backtrace(frames, (int)(sizeof(frames) / sizeof(frames[0])));
  dprintf(STDERR_FILENO,
          "APPBOX_DIAGNOSTIC_KILL pid=%d signal=%d frames=%d\n",
          process, signalNumber, count);
  backtrace_symbols_fd(frames, count, STDERR_FILENO);
  if (signalNumber == SIGKILL &&
      [NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-ignore-runtime-sigkill"]) {
    dprintf(STDERR_FILENO, "APPBOX_DIAGNOSTIC_KILL ignored\n");
    return 0;
  }
  return systemKill == NULL ? -1 : systemKill(process, signalNumber);
}

#define APPBOX_DYLD_INTERPOSE(_replacement, _replacee)                       \
  __attribute__((used)) static struct {                                      \
    const void *replacement;                                                 \
    const void *replacee;                                                    \
  } _appbox_interpose_##_replacee __attribute__((section("__DATA,__interpose"))) = { \
      (const void *)(unsigned long)&_replacement,                            \
      (const void *)(unsigned long)&_replacee};

typedef void (*AppBoxDispatchOnceFunction)(void *);
typedef void (*AppBoxDispatchOnceFFunction)(dispatch_once_t *, void *,
                                            AppBoxDispatchOnceFunction);
typedef void *(*AppBoxDlsymFunction)(void *, const char *);
typedef void *(*AppBoxGuestCallbackBuilderFunction)(
    void *, uint32_t, void *, uintptr_t, uintptr_t);
static AppBoxDispatchOnceFFunction AppBoxSystemDispatchOnceF;
static AppBoxDlsymFunction AppBoxSystemDlsym;
static uintptr_t AppBoxLastGuestCallbackAddress;
static AppBoxDispatchOnceFunction AppBoxLastGuestCallbackTrampoline;

static AppBoxDispatchOnceFunction
AppBoxGuestCallbackTrampoline(uintptr_t guestAddress) {
  uintptr_t cachedAddress = __atomic_load_n(
      &AppBoxLastGuestCallbackAddress, __ATOMIC_ACQUIRE);
  if (cachedAddress == guestAddress) {
    return __atomic_load_n(
        &AppBoxLastGuestCallbackTrampoline, __ATOMIC_RELAXED);
  }
  if (AppBoxDiagnosticAdversarysBase == 0 || guestAddress == 0) {
    return NULL;
  }

  // adversarys keeps every loaded guest image in a sorted runtime vector.
  // Its stock symbol resolver uses these same fields before calling the
  // signed callback-thunk builder at +0x7dc8. Reuse that mechanism for guest
  // function pointers passed as arguments to native APIs.
  void *runtime = *(void **)(AppBoxDiagnosticAdversarysBase + 0x062DE770);
  if (runtime == NULL) {
    return NULL;
  }
  uintptr_t imageCursor = *(uintptr_t *)((uintptr_t)runtime + 0x80);
  uintptr_t imageEnd = *(uintptr_t *)((uintptr_t)runtime + 0x88);
  if (imageCursor == 0 || imageEnd < imageCursor ||
      imageEnd - imageCursor > 0x20000 ||
      ((imageEnd - imageCursor) % sizeof(uintptr_t)) != 0) {
    return NULL;
  }

  void *guestImage = NULL;
  uintptr_t matchedImageStart = 0;
  uintptr_t matchedImageLimit = 0;
  NSUInteger matchedImageIndex = NSNotFound;
  NSUInteger imageIndex = 0;
  for (; imageCursor < imageEnd; imageCursor += sizeof(uintptr_t)) {
    void *candidate = *(void **)imageCursor;
    if (candidate == NULL) {
      imageIndex += 1;
      continue;
    }
    uintptr_t imageStart = *(uintptr_t *)((uintptr_t)candidate + 0x30);
    uintptr_t imageLimit = *(uintptr_t *)((uintptr_t)candidate + 0x38);
    if (guestAddress >= imageStart && guestAddress < imageLimit) {
      guestImage = candidate;
      matchedImageStart = imageStart;
      matchedImageLimit = imageLimit;
      matchedImageIndex = imageIndex;
      break;
    }
    imageIndex += 1;
  }
  if (guestImage == NULL) {
    char buffer[256] = {0};
    int length = snprintf(
        buffer, sizeof(buffer),
        "APPBOX_DIAGNOSTIC_GUEST_CALLBACK_MISS guest=%#lx "
        "vector_start=%#lx vector_end=%#lx\n",
        (unsigned long)guestAddress,
        (unsigned long)*(uintptr_t *)((uintptr_t)runtime + 0x80),
        (unsigned long)*(uintptr_t *)((uintptr_t)runtime + 0x88));
    if (length > 0) {
      size_t writeLength = (size_t)MIN(length, (int)sizeof(buffer) - 1);
      write(STDERR_FILENO, buffer, writeLength);
      if (AppBoxDiagnosticSignalFile >= 0) {
        write(AppBoxDiagnosticSignalFile, buffer, writeLength);
        fsync(AppBoxDiagnosticSignalFile);
      }
    }
    return NULL;
  }

  char matchBuffer[320] = {0};
  int matchLength = snprintf(
      matchBuffer, sizeof(matchBuffer),
      "APPBOX_DIAGNOSTIC_GUEST_CALLBACK_MATCH guest=%#lx image=%p "
      "index=%lu start=%#lx end=%#lx offset=%#lx\n",
      (unsigned long)guestAddress, guestImage,
      (unsigned long)matchedImageIndex, (unsigned long)matchedImageStart,
      (unsigned long)matchedImageLimit,
      (unsigned long)(guestAddress - matchedImageStart));
  if (matchLength > 0) {
    size_t writeLength =
        (size_t)MIN(matchLength, (int)sizeof(matchBuffer) - 1);
    write(STDERR_FILENO, matchBuffer, writeLength);
    if (AppBoxDiagnosticSignalFile >= 0) {
      write(AppBoxDiagnosticSignalFile, matchBuffer, writeLength);
      fsync(AppBoxDiagnosticSignalFile);
    }
  }

  AppBoxGuestCallbackBuilderFunction builder =
      (AppBoxGuestCallbackBuilderFunction)(
          AppBoxDiagnosticAdversarysBase + 0x00007DC8);
  AppBoxDispatchOnceFunction trampoline =
      (AppBoxDispatchOnceFunction)builder(
          runtime, 6, guestImage, guestAddress, 0);
  if (trampoline != NULL) {
    __atomic_store_n(
        &AppBoxLastGuestCallbackTrampoline, trampoline, __ATOMIC_RELAXED);
    __atomic_store_n(
        &AppBoxLastGuestCallbackAddress, guestAddress, __ATOMIC_RELEASE);
    NSLog(@"APPBOX_GUEST_CALLBACK resolved guest=%#lx trampoline=%p image=%p",
          (unsigned long)guestAddress, trampoline, guestImage);
  }
  return trampoline;
}

// Upgrade raw guest function pointers to adversarys callback trampolines while
// forwarding ordinary native callbacks unchanged.  Rebinding adversarys'
// general dlsym import also intercepts unrelated Dart VM symbol discovery.
__attribute__((used, noinline)) static void
AppBoxDispatchOnceBoundary(dispatch_once_t *predicate, void *context,
                           dispatch_function_t function) {
  if (AppBoxSystemDispatchOnceF == NULL) {
    AppBoxSystemDispatchOnceF =
        (AppBoxDispatchOnceFFunction)dlsym(RTLD_NEXT, "dispatch_once_f");
  }
  AppBoxDispatchOnceFunction translated =
      AppBoxGuestCallbackTrampoline((uintptr_t)function);
  if (translated != NULL) {
    NSLog(@"APPBOX_GUEST_CALLBACK dispatch_once guest=%p trampoline=%p",
          function, translated);
  }
  if (AppBoxSystemDispatchOnceF != NULL) {
    AppBoxSystemDispatchOnceF(
        predicate, context,
        translated == NULL ? (AppBoxDispatchOnceFunction)function : translated);
  }
}

// dyld interposition covers both normal imports and the native function
// pointer adversarys caches internally.  The boundary itself only changes a
// callback that belongs to a loaded guest image.
__attribute__((used, noinline)) static void
AppBoxObservedDispatchOnceFImpl(dispatch_once_t *predicate, void *context,
                                AppBoxDispatchOnceFunction function,
                                uintptr_t guestState) {
  if (AppBoxDiagnosticDispatchOnceArmed) {
    uintptr_t guestPC = *(const uintptr_t *)(guestState + 0x140);
    const uintptr_t *guestRegisters =
        (const uintptr_t *)(guestState + 0x40);
    char buffer[1024] = {0};
    int length = snprintf(
        buffer, sizeof(buffer),
        "APPBOX_DIAGNOSTIC_DISPATCH_ONCE function=%#lx predicate=%#lx "
        "context=%#lx state=%#lx state_pc=%#lx x0=%#lx x1=%#lx x2=%#lx "
        "x8=%#lx x19=%#lx x20=%#lx x25=%#lx x27=%#lx x28=%#lx "
        "sp=%#lx\n",
        (unsigned long)function, (unsigned long)predicate,
        (unsigned long)context, (unsigned long)guestState,
        (unsigned long)guestPC, (unsigned long)guestRegisters[0],
        (unsigned long)guestRegisters[1], (unsigned long)guestRegisters[2],
        (unsigned long)guestRegisters[8], (unsigned long)guestRegisters[19],
        (unsigned long)guestRegisters[20], (unsigned long)guestRegisters[25],
        (unsigned long)guestRegisters[27], (unsigned long)guestRegisters[28],
        (unsigned long)guestRegisters[31]);
    if (length > 0) {
      size_t writeLength =
          (size_t)MIN(length, (int)sizeof(buffer) - 1);
      write(STDERR_FILENO, buffer, writeLength);
      if (AppBoxDiagnosticSignalFile >= 0) {
        write(AppBoxDiagnosticSignalFile, buffer, writeLength);
        fsync(AppBoxDiagnosticSignalFile);
      }
    }
  }
  if (AppBoxSystemDispatchOnceF != NULL) {
    AppBoxDispatchOnceFunction translated =
        AppBoxGuestCallbackTrampoline((uintptr_t)function);
    AppBoxSystemDispatchOnceF(
        predicate, context, translated == NULL ? function : translated);
  }
}

__attribute__((used, naked)) static void
AppBoxObservedDispatchOnceF(dispatch_once_t *predicate, void *context,
                            AppBoxDispatchOnceFunction function) {
  __asm__("mov x3, x14\n"
          "b _AppBoxObservedDispatchOnceFImpl\n");
}

// Keep non-target dlsym calls ABI-identical to adversarys' original path: the
// naked observer compares the exact 16 bytes of "dispatch_once_f\0" and tail
// branches to dyld for every other symbol without adding a C frame or changing
// LR, SP or the guest-state register in X14.
__attribute__((used, naked)) static void *
AppBoxObservedDlsym(void *handle, const char *symbol) {
  __asm__("cbz x1, 2f\n"
          "ldp x2, x3, [x1]\n"
          "movz x4, #0x6964\n"
          "movk x4, #0x7073, lsl #16\n"
          "movk x4, #0x7461, lsl #32\n"
          "movk x4, #0x6863, lsl #48\n"
          "cmp x2, x4\n"
          "b.ne 2f\n"
          "movz x5, #0x6f5f\n"
          "movk x5, #0x636e, lsl #16\n"
          "movk x5, #0x5f65, lsl #32\n"
          "movk x5, #0x0066, lsl #48\n"
          "cmp x3, x5\n"
          "b.ne 2f\n"
          "adrp x0, _AppBoxObservedDispatchOnceF@PAGE\n"
          "add x0, x0, _AppBoxObservedDispatchOnceF@PAGEOFF\n"
          "ret\n"
          "2:\n"
          "adrp x9, _AppBoxSystemDlsym@PAGE\n"
          "ldr x9, [x9, _AppBoxSystemDlsym@PAGEOFF]\n"
          "cbz x9, 3f\n"
          "br x9\n"
          "3:\n"
          "mov x0, #0\n"
          "ret\n");
}

APPBOX_DYLD_INTERPOSE(AppBoxObservedConnect, connect)
APPBOX_DYLD_INTERPOSE(AppBoxObservedKill, kill)

static void AppBoxRebindObservedSymbolsInImage(
    const struct mach_header *rawHeader, intptr_t slide) {
  if (rawHeader == NULL || rawHeader->magic != MH_MAGIC_64) {
    return;
  }
  const struct mach_header_64 *header =
      (const struct mach_header_64 *)rawHeader;
  Dl_info imageInfo = {0};
  dladdr(rawHeader, &imageInfo);
  BOOL isAdversarys =
      imageInfo.dli_fname != NULL &&
      strstr(imageInfo.dli_fname, "/adversarys.framework/adversarys") != NULL;
  BOOL bridgeGuestDlsym =
      [NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-bridge-guest-callbacks"];
  BOOL bridgeDispatchOnceImport =
      [NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-bridge-dispatch-once-import"];
  BOOL observeConnect =
      [NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-observe-connect"];
  const struct symtab_command *symbolTableCommand = NULL;
  const struct dysymtab_command *dynamicSymbolTableCommand = NULL;
  const struct segment_command_64 *linkeditSegment = NULL;
  uintptr_t commandCursor = (uintptr_t)header + sizeof(*header);
  for (uint32_t index = 0; index < header->ncmds; index += 1) {
    const struct load_command *command =
        (const struct load_command *)commandCursor;
    if (command->cmd == LC_SYMTAB) {
      symbolTableCommand = (const struct symtab_command *)command;
    } else if (command->cmd == LC_DYSYMTAB) {
      dynamicSymbolTableCommand =
          (const struct dysymtab_command *)command;
    } else if (command->cmd == LC_SEGMENT_64) {
      const struct segment_command_64 *segment =
          (const struct segment_command_64 *)command;
      if (strcmp(segment->segname, SEG_LINKEDIT) == 0) {
        linkeditSegment = segment;
      }
    }
    commandCursor += command->cmdsize;
  }
  if (symbolTableCommand == NULL || dynamicSymbolTableCommand == NULL ||
      linkeditSegment == NULL) {
    return;
  }

  uintptr_t linkeditBase = (uintptr_t)slide + linkeditSegment->vmaddr -
      linkeditSegment->fileoff;
  const struct nlist_64 *symbols = (const struct nlist_64 *)(
      linkeditBase + symbolTableCommand->symoff);
  const char *strings = (const char *)(linkeditBase +
                                      symbolTableCommand->stroff);
  const uint32_t *indirectSymbols = (const uint32_t *)(
      linkeditBase + dynamicSymbolTableCommand->indirectsymoff);

  commandCursor = (uintptr_t)header + sizeof(*header);
  for (uint32_t commandIndex = 0; commandIndex < header->ncmds;
       commandIndex += 1) {
    const struct load_command *command =
        (const struct load_command *)commandCursor;
    if (command->cmd == LC_SEGMENT_64) {
      const struct segment_command_64 *segment =
          (const struct segment_command_64 *)command;
      const struct section_64 *sections =
          (const struct section_64 *)(segment + 1);
      for (uint32_t sectionIndex = 0; sectionIndex < segment->nsects;
           sectionIndex += 1) {
        const struct section_64 *section = &sections[sectionIndex];
        uint32_t sectionType = section->flags & SECTION_TYPE;
        if (sectionType != S_LAZY_SYMBOL_POINTERS &&
            sectionType != S_NON_LAZY_SYMBOL_POINTERS) {
          continue;
        }
        uintptr_t *bindings = (uintptr_t *)(slide + section->addr);
        uint32_t bindingCount = (uint32_t)(section->size / sizeof(uintptr_t));
        for (uint32_t bindingIndex = 0; bindingIndex < bindingCount;
             bindingIndex += 1) {
          uint32_t symbolIndex =
              indirectSymbols[section->reserved1 + bindingIndex];
          if (symbolIndex == INDIRECT_SYMBOL_ABS ||
              symbolIndex == INDIRECT_SYMBOL_LOCAL ||
              symbolIndex == (INDIRECT_SYMBOL_LOCAL | INDIRECT_SYMBOL_ABS)) {
            continue;
          }
          const char *name = strings + symbols[symbolIndex].n_un.n_strx;
          BOOL rebindConnect =
              observeConnect && name != NULL && strcmp(name, "_connect") == 0;
          BOOL rebindDlsym =
              isAdversarys && bridgeGuestDlsym && name != NULL &&
              strcmp(name, "_dlsym") == 0;
          BOOL rebindDispatchOnce =
              isAdversarys && bridgeDispatchOnceImport && name != NULL &&
              strcmp(name, "_dispatch_once_f") == 0;
          if (!rebindConnect && !rebindDlsym && !rebindDispatchOnce) {
            continue;
          }
          vm_address_t page = (vm_address_t)&bindings[bindingIndex] &
              ~((vm_address_t)vm_page_size - 1);
          kern_return_t protection = vm_protect(
              mach_task_self(), page, vm_page_size, false,
              VM_PROT_READ | VM_PROT_WRITE | VM_PROT_COPY);
          if (protection != KERN_SUCCESS) {
            NSLog(@"APPBOX_CONNECT rebind_protect_failed code=%d", protection);
            continue;
          }
          if (rebindDlsym) {
            if (AppBoxSystemDlsym == NULL) {
              AppBoxSystemDlsym =
                  (AppBoxDlsymFunction)bindings[bindingIndex];
            }
            bindings[bindingIndex] = (uintptr_t)&AppBoxObservedDlsym;
            NSLog(@"APPBOX_DIAGNOSTIC_DISPATCH_ONCE dlsym_rebound "
                  "image=%s section=%s",
                  imageInfo.dli_fname ?: "unknown", section->sectname);
          } else if (rebindDispatchOnce) {
            if (AppBoxSystemDispatchOnceF == NULL) {
              AppBoxSystemDispatchOnceF =
                  (AppBoxDispatchOnceFFunction)bindings[bindingIndex];
            }
            bindings[bindingIndex] =
                (uintptr_t)&AppBoxDispatchOnceBoundary;
            NSLog(@"APPBOX_GUEST_CALLBACK dispatch_once_import_rebound "
                  "image=%s section=%s original=%p",
                  imageInfo.dli_fname ?: "unknown", section->sectname,
                  AppBoxSystemDispatchOnceF);
          } else {
            bindings[bindingIndex] = (uintptr_t)&AppBoxObservedConnect;
            NSLog(@"APPBOX_CONNECT rebound image=%s section=%s",
                  imageInfo.dli_fname ?: "unknown", section->sectname);
          }
        }
      }
    }
    commandCursor += command->cmdsize;
  }
}

static void AppBoxInstallConnectObservation(void) {
  uint32_t count = _dyld_image_count();
  for (uint32_t index = 0; index < count; index += 1) {
    AppBoxRebindObservedSymbolsInImage(
        _dyld_get_image_header(index),
        _dyld_get_image_vmaddr_slide(index));
  }
  _dyld_register_func_for_add_image(AppBoxRebindObservedSymbolsInImage);
  NSLog(@"APPBOX_CONNECT observation_installed images=%u", count);
}

static void AppBoxInstallGuestCallbackBridges(void) {
  uint32_t count = _dyld_image_count();
  for (uint32_t index = 0; index < count; index += 1) {
    AppBoxRebindObservedSymbolsInImage(
        _dyld_get_image_header(index),
        _dyld_get_image_vmaddr_slide(index));
  }
  if (AppBoxSystemDispatchOnceF == NULL && AppBoxSystemDlsym != NULL) {
    AppBoxSystemDispatchOnceF = (AppBoxDispatchOnceFFunction)
        AppBoxSystemDlsym(RTLD_DEFAULT, "dispatch_once_f");
  }
  NSLog(@"APPBOX_GUEST_CALLBACK bridges_installed images=%u "
        "dlsym=%p dispatch_once_f=%p",
        count, AppBoxSystemDlsym, AppBoxSystemDispatchOnceF);
}

static int AppBoxDyzbGuestKiwiInitBridge(id receiver, SEL selector,
                                         const char *configuration) {
  (void)receiver;
  NSLog(@"APPBOX_KIWI_CLASS init_start main=%d", NSThread.isMainThread);
  int result = ((int (*)(id, SEL, const char *))AppBoxNativeKiwiInit)(
      AppBoxNativeKiwiClass, selector, configuration);
  NSLog(@"APPBOX_KIWI_CLASS init_return result=%d", result);
  return result;
}

static NSString *AppBoxImageForAddress(const void *address) {
  Dl_info imageInfo = {0};
  if (address == NULL || dladdr(address, &imageInfo) == 0 ||
      imageInfo.dli_fname == NULL) {
    return @"unknown";
  }
  return [NSString stringWithUTF8String:imageInfo.dli_fname].lastPathComponent;
}

// Kiwi's stock implementation runs the supplied completion block on an
// NSOperationQueue.  A translated guest block may only be safely entered from
// the main thread, so keep the real network initialization and bridge just its
// completion back to the main queue.
static int AppBoxKiwiInitWithListenerBridge(id receiver, SEL selector,
                                             const char *configuration,
                                             id listener) {
  const void *guestInvoke = NULL;
  if (listener != nil) {
    guestInvoke = ((const void *const *)(__bridge const void *)listener)[2];
  }
  NSLog(@"APPBOX_KIWI_BRIDGE start listener=%p invoke=%p image=%@ main=%d",
        (__bridge void *)listener, guestInvoke,
        AppBoxImageForAddress(guestInvoke), NSThread.isMainThread);

  id guestListener = [listener copy];
  void (^hostListener)(int) = ^(int result) {
    NSLog(@"APPBOX_KIWI_BRIDGE native_complete result=%d main=%d", result,
          NSThread.isMainThread);
    dispatch_async(dispatch_get_main_queue(), ^{
      NSLog(@"APPBOX_KIWI_BRIDGE guest_callback result=%d invoke=%p image=%@",
            result, guestInvoke, AppBoxImageForAddress(guestInvoke));
      if (guestListener != nil) {
        ((void (^)(int))guestListener)(result);
      }
      NSLog(@"APPBOX_KIWI_BRIDGE guest_callback_returned result=%d", result);
    });
  };
  return ((AppBoxKiwiInitWithListenerFunction)
      AppBoxOriginalKiwiInitWithListener)(receiver, selector, configuration,
                                          hostListener);
}

static BOOL AppBoxInstallKiwiListenerBridge(void) {
  Class kiwiClass = NSClassFromString(@"Kiwi");
  SEL selector = NSSelectorFromString(@"InitWithListener::");
  Method method = kiwiClass == Nil
      ? NULL
      : class_getClassMethod(kiwiClass, selector);
  if (method == NULL) {
    NSLog(@"APPBOX_KIWI_BRIDGE install_failed class=%@",
          NSStringFromClass(kiwiClass));
    return NO;
  }
  AppBoxNativeKiwiClass = kiwiClass;
  IMP current = method_getImplementation(method);
  if (current != (IMP)AppBoxKiwiInitWithListenerBridge) {
    AppBoxOriginalKiwiInitWithListener = current;
    method_setImplementation(method, (IMP)AppBoxKiwiInitWithListenerBridge);
  }
  NSLog(@"APPBOX_KIWI_BRIDGE installed original=%p image=%@", current,
        AppBoxImageForAddress((const void *)current));
  return YES;
}

static id AppBoxFlutterCallArguments(id call) {
  SEL selector = NSSelectorFromString(@"arguments");
  if (call == nil || ![call respondsToSelector:selector]) {
    return nil;
  }
  return ((id (*)(id, SEL))objc_msgSend)(call, selector);
}

static void AppBoxNativeYunCengHandleMethodCall(id plugin, SEL selector,
                                                id call, id resultCallback) {
  (void)selector;
  SEL methodSelector = NSSelectorFromString(@"method");
  NSString *method = [call respondsToSelector:methodSelector]
      ? ((id (*)(id, SEL))objc_msgSend)(call, methodSelector)
      : nil;
  NSDictionary *arguments = AppBoxFlutterCallArguments(call);
  const uintptr_t *resultWords = resultCallback == nil
      ? NULL
      : (const uintptr_t *)(__bridge const void *)resultCallback;
  id resultCodec = resultWords == NULL
      ? nil
      : (__bridge id)(void *)resultWords[4];
  id binaryReply = resultWords == NULL
      ? nil
      : (__bridge id)(void *)resultWords[5];
  const void *binaryReplyInvoke = binaryReply == nil
      ? NULL
      : ((const void *const *)(__bridge const void *)binaryReply)[2];
  NSLog(@"APPBOX_NATIVE_YUNCENG call method=%@ result_image=%@ "
         "codec=%@/%s binary_reply_image=%@",
        method,
        resultCallback == nil
            ? @"none"
            : AppBoxImageForAddress(
                  ((const void *const *)(__bridge const void *)
                      resultCallback)[2]),
        NSStringFromClass([resultCodec class]),
        resultCodec == nil
            ? "none"
            : (class_getImageName([resultCodec class]) ?: "unknown"),
        AppBoxImageForAddress(binaryReplyInvoke));

  int code = -1;
  BOOL focusInstallResult = NO;
  id resultValue = nil;
  if ([method isEqualToString:@"initEx"]) {
    NSString *token = [arguments isKindOfClass:NSDictionary.class]
        ? arguments[@"token"]
        : nil;
    NSString *appKey = [arguments isKindOfClass:NSDictionary.class]
        ? arguments[@"appKey"]
        : nil;
    if ([token isKindOfClass:NSString.class]) {
      objc_setAssociatedObject(plugin,
                               &AppBoxNativeYunCengTokenAssociationKey,
                               token, OBJC_ASSOCIATION_COPY_NONATOMIC);
    }
    Class kiwiClass = AppBoxNativeKiwiClass ?: NSClassFromString(@"Kiwi");
    SEL initSelector = NSSelectorFromString(@"Init:");
    Method initMethod = kiwiClass == Nil
        ? NULL
        : class_getClassMethod(kiwiClass, initSelector);
    if (initMethod != NULL && [appKey isKindOfClass:NSString.class]) {
      int (*initFunction)(id, SEL, const char *) =
          (int (*)(id, SEL, const char *))method_getImplementation(initMethod);
      code = initFunction(kiwiClass, initSelector, appKey.UTF8String);
    }
    resultValue = @(code);
  } else if ([method isEqualToString:@"restartAllServer"]) {
    Class kiwiClass = AppBoxNativeKiwiClass ?: NSClassFromString(@"Kiwi");
    SEL restartSelector = NSSelectorFromString(@"RestartAllServer");
    Method restartMethod = kiwiClass == Nil
        ? NULL
        : class_getClassMethod(kiwiClass, restartSelector);
    if (restartMethod != NULL) {
      code = ((int (*)(id, SEL))method_getImplementation(restartMethod))(
          kiwiClass, restartSelector);
    }
    resultValue = @(code);
  } else if ([method isEqualToString:@"getProxyTcpByDomain"]) {
    NSString *groupName = [arguments isKindOfClass:NSDictionary.class]
        ? arguments[@"group_name"]
        : nil;
    NSString *directDomain = [arguments isKindOfClass:NSDictionary.class]
        ? arguments[@"ddomain"]
        : nil;
    id directPort = [arguments isKindOfClass:NSDictionary.class]
        ? arguments[@"dport"]
        : nil;
    focusInstallResult = [groupName isEqualToString:@"kiwi_install"];
    char targetIP[128] = {0};
    char targetPort[40] = {0};
    Class kiwiClass = AppBoxNativeKiwiClass ?: NSClassFromString(@"Kiwi");
    SEL proxySelector = NSSelectorFromString(@"ServerToLocal:::::");
    Method proxyMethod = kiwiClass == Nil
        ? NULL
        : class_getClassMethod(kiwiClass, proxySelector);
    if (proxyMethod != NULL && [groupName isKindOfClass:NSString.class]) {
      int (*proxyFunction)(id, SEL, const char *, char *, int, char *, int) =
          (int (*)(id, SEL, const char *, char *, int, char *, int))
              method_getImplementation(proxyMethod);
      code = proxyFunction(kiwiClass, proxySelector, groupName.UTF8String,
                           targetIP, (int)sizeof(targetIP), targetPort,
                           (int)sizeof(targetPort));
    }
    NSString *targetIPString = [NSString stringWithUTF8String:targetIP] ?: @"";
    NSString *targetPortString =
        [NSString stringWithUTF8String:targetPort] ?: @"";
    NSMutableDictionary *proxyResult = [NSMutableDictionary dictionary];
    [proxyResult setObject:[NSString stringWithFormat:@"%i", code]
                    forKey:@"code"];
    [proxyResult setObject:targetIPString forKey:@"target_ip"];
    [proxyResult setObject:targetPortString forKey:@"target_port"];
    resultValue = proxyResult;
    NSLog(@"APPBOX_NATIVE_YUNCENG proxy group=%@ direct=%@:%@ code=%d "
           "target=%@:%@ main=%d",
          groupName, directDomain, directPort, code, targetIPString,
          targetPortString, NSThread.isMainThread);
    if (code == 0 && targetIPString.length > 0 &&
        targetPortString.integerValue > 0 &&
        [NSProcessInfo.processInfo.arguments
            containsObject:@"--appbox-probe-local-proxy"]) {
      AppBoxProbeLocalProxy(targetIPString, targetPortString);
    }
  }
  NSLog(@"APPBOX_NATIVE_YUNCENG result method=%@ code=%d", method, code);
  if (resultCallback != nil) {
    if ([method isEqualToString:@"initEx"] &&
        [NSProcessInfo.processInfo.arguments
            containsObject:@"--appbox-debug-delay-kiwi-result"]) {
      id delayedCallback = [resultCallback copy];
      id delayedValue = resultValue ?: @(code);
      NSLog(@"APPBOX_NATIVE_YUNCENG delaying_init_result seconds=15");
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 15 * NSEC_PER_SEC),
                     dispatch_get_main_queue(), ^{
        NSLog(@"APPBOX_NATIVE_YUNCENG delivering_delayed_init_result");
        ((void (^)(id))delayedCallback)(delayedValue);
      });
      return;
    }
    if ([method isEqualToString:@"getProxyTcpByDomain"]) {
      AppBoxStartDiagnosticBurst(method);
      AppBoxStartDiagnosticFileBurst(method);
    }
    if (focusInstallResult &&
        [NSProcessInfo.processInfo.arguments
            containsObject:@"--appbox-diagnostic-focused-result"]) {
      AppBoxStartDiagnosticFocusedBurst();
    }
    if (focusInstallResult &&
        [NSProcessInfo.processInfo.arguments
            containsObject:@"--appbox-async-kiwi-install-result"]) {
      id delayedCallback = [resultCallback copy];
      id delayedValue = resultValue ?: @(code);
      NSLog(@"APPBOX_NATIVE_YUNCENG scheduling_async_install_result");
      dispatch_async(dispatch_get_main_queue(), ^{
        NSLog(@"APPBOX_NATIVE_YUNCENG delivering_async_install_result");
        ((void (^)(id))delayedCallback)(delayedValue);
        NSLog(@"APPBOX_NATIVE_YUNCENG async_install_result_returned");
      });
      return;
    }
    ((void (^)(id))resultCallback)(resultValue ?: @(code));
    NSLog(@"APPBOX_NATIVE_YUNCENG result_returned method=%@ code=%d", method,
          code);
  }
}

static void AppBoxNativeYunCengRegister(id pluginClass, SEL selector,
                                        id registrar) {
  (void)selector;
  id existingPlugin = objc_getAssociatedObject(
      registrar, &AppBoxNativeYunCengPluginAssociationKey);
  if (existingPlugin != nil) {
    NSLog(@"APPBOX_NATIVE_YUNCENG register_skipped reason=already_registered");
    return;
  }
  SEL messengerSelector = NSSelectorFromString(@"messenger");
  id messenger = ((id (*)(id, SEL))objc_msgSend)(registrar,
                                                  messengerSelector);
  Class channelClass = AppBoxNativeFlutterMethodChannelClass ?:
      NSClassFromString(@"FlutterMethodChannel");
  SEL channelSelector =
      NSSelectorFromString(@"methodChannelWithName:binaryMessenger:");
  Method channelFactory = channelClass == Nil
      ? NULL
      : class_getClassMethod(channelClass, channelSelector);
  id channel = ((id (*)(id, SEL, id, id))objc_msgSend)(
      channelClass, channelSelector, @"flutter_yun_ceng_kiwi", messenger);
  id plugin = ((id (*)(id, SEL))objc_msgSend)(pluginClass,
                                               NSSelectorFromString(@"new"));
  // Calling FlutterPluginRegistrar's addMethodCallDelegate here re-enters the
  // translated guest registrar.  Its wrapper manufactures a result block in
  // adversarys, so the native result dictionary has to cross back through the
  // VM before Flutter's codec can send it to Dart.  Register directly on the
  // process-wide native FlutterMethodChannel instead.  That keeps decoding,
  // the result callback, envelope encoding, and binary reply in Flutter.framework.
  id handler = [^(id call, id resultCallback) {
    AppBoxNativeYunCengHandleMethodCall(
        plugin, NSSelectorFromString(@"handleMethodCall:result:"), call,
        resultCallback);
  } copy];
  SEL handlerSelector = NSSelectorFromString(@"setMethodCallHandler:");
  ((void (*)(id, SEL, id))objc_msgSend)(channel, handlerSelector, handler);
  objc_setAssociatedObject(registrar,
                           &AppBoxNativeYunCengPluginAssociationKey,
                           plugin, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(plugin,
                           &AppBoxNativeYunCengChannelAssociationKey,
                           channel, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  objc_setAssociatedObject(plugin,
                           &AppBoxNativeYunCengHandlerAssociationKey,
                           handler, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
  Method handlerMethod = channelClass == Nil
      ? NULL
      : class_getInstanceMethod(channelClass, handlerSelector);
  NSLog(@"APPBOX_NATIVE_YUNCENG registered class=%@ registrar=%@/%s "
         "messenger=%@/%s channel=%@/%s factory_image=%@ handler_image=%@",
        NSStringFromClass(pluginClass), NSStringFromClass([registrar class]),
        class_getImageName([registrar class]) ?: "unknown",
        NSStringFromClass([messenger class]),
        class_getImageName([messenger class]) ?: "unknown", channel,
        class_getImageName([channel class]) ?: "unknown",
        AppBoxImageForAddress(channelFactory == NULL
                                  ? NULL
                                  : (const void *)method_getImplementation(
                                        channelFactory)),
        AppBoxImageForAddress(handlerMethod == NULL
                                  ? NULL
                                  : (const void *)method_getImplementation(
                                        handlerMethod)));
}

static BOOL AppBoxInstallNativeYunCengPluginClass(void) {
  // Capture this before adversarys opens the guest Flutter.framework.  After
  // that point NSClassFromString resolves the translated duplicate instead of
  // the already-loaded native Flutter.framework class.
  AppBoxNativeFlutterMethodChannelClass =
      NSClassFromString(@"FlutterMethodChannel");
  NSLog(@"APPBOX_NATIVE_YUNCENG native_channel_class=%p image=%s",
        AppBoxNativeFlutterMethodChannelClass,
        AppBoxNativeFlutterMethodChannelClass == Nil
            ? "missing"
            : (class_getImageName(AppBoxNativeFlutterMethodChannelClass) ?:
               "unknown"));
  Class existing = NSClassFromString(@"FlutterYunCengKiwiPlugin");
  if (existing != Nil) {
    AppBoxNativeYunCengPluginClass = existing;
    return YES;
  }
  Class pluginClass = objc_allocateClassPair(
      NSObject.class, "FlutterYunCengKiwiPlugin", 0);
  if (pluginClass == Nil) {
    NSLog(@"APPBOX_NATIVE_YUNCENG class_allocate_failed");
    return NO;
  }
  class_addMethod(pluginClass,
                  NSSelectorFromString(@"handleMethodCall:result:"),
                  (IMP)AppBoxNativeYunCengHandleMethodCall,
                  "v32@0:8@16@?24");
  class_addMethod(object_getClass(pluginClass),
                  NSSelectorFromString(@"registerWithRegistrar:"),
                  (IMP)AppBoxNativeYunCengRegister,
                  "v24@0:8@16");
  objc_registerClassPair(pluginClass);
  AppBoxNativeYunCengPluginClass = pluginClass;
  NSLog(@"APPBOX_NATIVE_YUNCENG class_ready class=%p", pluginClass);
  return YES;
}

static void AppBoxDyzbKiwiInitExBridge(id plugin, SEL selector, id call,
                                        id resultCallback) {
  (void)selector;
  NSDictionary *arguments = AppBoxFlutterCallArguments(call);
  NSString *token = [arguments isKindOfClass:NSDictionary.class]
      ? arguments[@"token"]
      : nil;
  NSString *appKey = [arguments isKindOfClass:NSDictionary.class]
      ? arguments[@"appKey"]
      : nil;
  Ivar tokenIvar = class_getInstanceVariable([plugin class], "_token");
  if (tokenIvar != NULL && [token isKindOfClass:NSString.class]) {
    object_setIvar(plugin, tokenIvar, token);
  }

  Class kiwiClass = AppBoxNativeKiwiClass ?: NSClassFromString(@"Kiwi");
  SEL initSelector = NSSelectorFromString(@"Init:");
  Method initMethod = kiwiClass == Nil
      ? NULL
      : class_getClassMethod(kiwiClass, initSelector);
  NSLog(@"APPBOX_KIWI_PLUGIN init_start class=%@ app_key_length=%lu main=%d",
        NSStringFromClass(kiwiClass), (unsigned long)appKey.length,
        NSThread.isMainThread);
  int code = -1;
  if (initMethod != NULL && [appKey isKindOfClass:NSString.class]) {
    int (*initFunction)(id, SEL, const char *) =
        (int (*)(id, SEL, const char *))method_getImplementation(initMethod);
    code = initFunction(kiwiClass, initSelector, appKey.UTF8String);
  }
  NSLog(@"APPBOX_KIWI_PLUGIN init_return code=%d", code);
  if (resultCallback != nil) {
    id copiedResultCallback = [resultCallback copy];
    const void *resultInvoke =
        ((const void *const *)(__bridge const void *)copiedResultCallback)[2];
    NSLog(@"APPBOX_KIWI_PLUGIN result_scheduled block=%p invoke=%p image=%@",
          (__bridge void *)resultCallback, resultInvoke,
          AppBoxImageForAddress(resultInvoke));
    dispatch_async(dispatch_get_main_queue(), ^{
      NSLog(@"APPBOX_KIWI_PLUGIN result_start code=%d", code);
      ((void (^)(id))copiedResultCallback)(@(code));
      NSLog(@"APPBOX_KIWI_PLUGIN result_returned code=%d", code);
    });
  }
}

static BOOL AppBoxInstallDyzbKiwiPluginBridge(void) {
  Class pluginClass = NSClassFromString(@"FlutterYunCengKiwiPlugin");
  SEL selector = NSSelectorFromString(@"initEx:result:");
  Method method = pluginClass == Nil
      ? NULL
      : class_getInstanceMethod(pluginClass, selector);
  if (method == NULL) {
    NSLog(@"APPBOX_KIWI_PLUGIN install_failed class=%@",
          NSStringFromClass(pluginClass));
    return NO;
  }
  IMP original = method_getImplementation(method);
  method_setImplementation(method, (IMP)AppBoxDyzbKiwiInitExBridge);
  NSLog(@"APPBOX_KIWI_PLUGIN installed original=%p image=%@", original,
        AppBoxImageForAddress((const void *)original));
  return YES;
}

static void AppBoxPrepareDyzbKiwiThenRunGuest(id plugin, SEL selector, id call,
                                               id resultCallback) {
  NSDictionary *arguments = AppBoxFlutterCallArguments(call);
  NSString *appKey = [arguments isKindOfClass:NSDictionary.class]
      ? arguments[@"appKey"]
      : nil;
  Class kiwiClass = AppBoxNativeKiwiClass ?: NSClassFromString(@"Kiwi");
  SEL initSelector = NSSelectorFromString(@"Init:");
  Method initMethod = kiwiClass == Nil
      ? NULL
      : class_getClassMethod(kiwiClass, initSelector);
  int code = -1;
  if (initMethod != NULL && [appKey isKindOfClass:NSString.class]) {
    int (*initFunction)(id, SEL, const char *) =
        (int (*)(id, SEL, const char *))method_getImplementation(initMethod);
    NSLog(@"APPBOX_KIWI_PREPARE native_start app_key_length=%lu",
          (unsigned long)appKey.length);
    code = initFunction(kiwiClass, initSelector, appKey.UTF8String);
    NSLog(@"APPBOX_KIWI_PREPARE native_return code=%d", code);
  }
  NSLog(@"APPBOX_KIWI_PREPARE guest_enter imp=%p image=%@",
        AppBoxOriginalDyzbKiwiInitEx,
        AppBoxImageForAddress((const void *)AppBoxOriginalDyzbKiwiInitEx));
  Method method = class_getInstanceMethod([plugin class], selector);
  if (method != NULL) {
    method_setImplementation(method, AppBoxOriginalDyzbKiwiInitEx);
  }
  ((void (*)(id, SEL, id, id))objc_msgSend)(plugin, selector, call,
                                            resultCallback);
  NSLog(@"APPBOX_KIWI_PREPARE guest_returned");
}

static BOOL AppBoxInstallDyzbKiwiPrepareBridge(void) {
  Class pluginClass = NSClassFromString(@"FlutterYunCengKiwiPlugin");
  SEL selector = NSSelectorFromString(@"initEx:result:");
  Method method = pluginClass == Nil
      ? NULL
      : class_getInstanceMethod(pluginClass, selector);
  if (method == NULL) {
    NSLog(@"APPBOX_KIWI_PREPARE install_failed class=%@",
          NSStringFromClass(pluginClass));
    return NO;
  }
  AppBoxOriginalDyzbKiwiInitEx = method_getImplementation(method);
  method_setImplementation(method, (IMP)AppBoxPrepareDyzbKiwiThenRunGuest);
  NSLog(@"APPBOX_KIWI_PREPARE installed original=%p image=%@",
        AppBoxOriginalDyzbKiwiInitEx,
        AppBoxImageForAddress((const void *)AppBoxOriginalDyzbKiwiInitEx));
  return YES;
}

static BOOL AppBoxInstallDyzbKiwiClassBridge(void) {
  if (AppBoxNativeKiwiClass == Nil) {
    NSLog(@"APPBOX_KIWI_CLASS install_failed reason=native_class_missing");
    return NO;
  }
  int classCount = objc_getClassList(NULL, 0);
  if (classCount <= 0) {
    NSLog(@"APPBOX_KIWI_CLASS install_failed reason=empty_class_list");
    return NO;
  }
  __unsafe_unretained Class *classes =
      (__unsafe_unretained Class *)calloc((size_t)classCount, sizeof(Class));
  classCount = objc_getClassList(classes, classCount);
  Class guestKiwiClass = Nil;
  for (int index = 0; index < classCount; index += 1) {
    Class candidate = classes[index];
    if (candidate == AppBoxNativeKiwiClass ||
        strcmp(class_getName(candidate), "Kiwi") != 0) {
      continue;
    }
    guestKiwiClass = candidate;
    break;
  }
  free(classes);
  if (guestKiwiClass == Nil) {
    NSLog(@"APPBOX_KIWI_CLASS install_failed reason=guest_class_missing ");
    return NO;
  }

  unsigned int methodCount = 0;
  Method *guestMethods = class_copyMethodList(
      object_getClass(guestKiwiClass), &methodCount);
  unsigned int replaced = 0;
  for (unsigned int index = 0; index < methodCount; index += 1) {
    Method guestMethod = guestMethods[index];
    SEL selector = method_getName(guestMethod);
    Method nativeMethod = class_getClassMethod(AppBoxNativeKiwiClass, selector);
    if (nativeMethod == NULL ||
        strcmp(method_getTypeEncoding(guestMethod),
               method_getTypeEncoding(nativeMethod)) != 0) {
      continue;
    }
    IMP guestIMP = method_getImplementation(guestMethod);
    IMP nativeIMP = method_getImplementation(nativeMethod);
    IMP replacement = nativeIMP;
    if (strcmp(sel_getName(selector), "Init:") == 0) {
      AppBoxNativeKiwiInit = nativeIMP;
      replacement = (IMP)AppBoxDyzbGuestKiwiInitBridge;
    }
    method_setImplementation(guestMethod, replacement);
    replaced += 1;
    NSLog(@"APPBOX_KIWI_CLASS replaced selector=%@ guest_imp=%p guest_image=%@ "
          "native_imp=%p native_image=%@",
          NSStringFromSelector(selector), guestIMP,
          AppBoxImageForAddress((const void *)guestIMP), nativeIMP,
          AppBoxImageForAddress((const void *)nativeIMP));
  }
  free(guestMethods);
  NSLog(@"APPBOX_KIWI_CLASS installed guest=%p native=%p methods=%u",
        guestKiwiClass, AppBoxNativeKiwiClass, replaced);
  return replaced > 0;
}

static char *AppBoxAppendSignalText(char *cursor, const char *text) {
  while (*text != '\0') {
    *cursor++ = *text++;
  }
  return cursor;
}

static char *AppBoxAppendSignalHex(char *cursor, uintptr_t value) {
  static const char digits[] = "0123456789abcdef";
  *cursor++ = '0';
  *cursor++ = 'x';
  BOOL emitted = NO;
  for (int shift = (int)(sizeof(value) * 8) - 4; shift >= 0; shift -= 4) {
    unsigned digit = (unsigned)((value >> shift) & 0xF);
    if (digit != 0 || emitted || shift == 0) {
      *cursor++ = digits[digit];
      emitted = YES;
    }
  }
  return cursor;
}

static void AppBoxDiagnosticSignalHandler(int signalNumber,
                                          siginfo_t *signalInfo,
                                          void *rawContext) {
  ucontext_t *context = (ucontext_t *)rawContext;
  uintptr_t pc = context->uc_mcontext->__ss.__pc;
  uintptr_t lr = context->uc_mcontext->__ss.__lr;
  uintptr_t adversarysOffset = pc - AppBoxDiagnosticAdversarysBase;
  if (adversarysOffset == 0x0088BC30 && !AppBoxDiagnosticWatchArmed) {
    uintptr_t guestState = context->uc_mcontext->__ss.__x[14];
    AppBoxDiagnosticWatchGuestState = guestState;
    const uintptr_t *guestRegisters =
        (const uintptr_t *)(guestState + 0x40);
    AppBoxDiagnosticWatchAddress = guestRegisters[31] + 0x10;
    arm_debug_state64_t debugState = {0};
    mach_msg_type_number_t debugStateCount = ARM_DEBUG_STATE64_COUNT;
    thread_t currentThread = mach_thread_self();
    kern_return_t getResult = thread_get_state(
        currentThread, ARM_DEBUG_STATE64, (thread_state_t)&debugState,
        &debugStateCount);
    kern_return_t setResult = KERN_FAILURE;
    if (getResult == KERN_SUCCESS) {
      debugState.__wvr[0] = AppBoxDiagnosticWatchAddress;
      debugState.__wcr[0] = 0x1FF5;
      setResult = thread_set_state(
          currentThread, ARM_DEBUG_STATE64, (thread_state_t)&debugState,
          ARM_DEBUG_STATE64_COUNT);
    }
    mach_port_deallocate(mach_task_self(), currentThread);
    char setupBuffer[256];
    char *setupCursor = AppBoxAppendSignalText(
        setupBuffer, "APPBOX_DIAGNOSTIC_WATCH_SETUP address=");
    setupCursor = AppBoxAppendSignalHex(
        setupCursor, AppBoxDiagnosticWatchAddress);
    setupCursor = AppBoxAppendSignalText(setupCursor, " get=");
    setupCursor = AppBoxAppendSignalHex(setupCursor, (uintptr_t)getResult);
    setupCursor = AppBoxAppendSignalText(setupCursor, " set=");
    setupCursor = AppBoxAppendSignalHex(setupCursor, (uintptr_t)setResult);
    *setupCursor++ = '\n';
    write(STDERR_FILENO, setupBuffer, (size_t)(setupCursor - setupBuffer));
    if (setResult == KERN_SUCCESS) {
      AppBoxDiagnosticWatchArmed = 1;
      context->uc_mcontext->__ss.__pc += 4;
      return;
    }
  }
  char buffer[2048];
  char *cursor = AppBoxAppendSignalText(buffer, "APPBOX_DIAGNOSTIC_SIGNAL signal=");
  *cursor++ = (char)('0' + signalNumber / 10);
  *cursor++ = (char)('0' + signalNumber % 10);
  cursor = AppBoxAppendSignalText(cursor, " fault=");
  cursor = AppBoxAppendSignalHex(
      cursor, (uintptr_t)(signalInfo == NULL ? NULL : signalInfo->si_addr));
  cursor = AppBoxAppendSignalText(cursor, " pc=");
  cursor = AppBoxAppendSignalHex(cursor, pc);
  cursor = AppBoxAppendSignalText(cursor, " adversarys_offset=");
  cursor = AppBoxAppendSignalHex(cursor, pc - AppBoxDiagnosticAdversarysBase);
  cursor = AppBoxAppendSignalText(cursor, " lr=");
  cursor = AppBoxAppendSignalHex(cursor, lr);
  cursor = AppBoxAppendSignalText(cursor, " sp=");
  cursor = AppBoxAppendSignalHex(cursor, context->uc_mcontext->__ss.__sp);
  static const unsigned diagnosticRegisters[] = {
      0, 1, 2, 3, 4, 5, 6, 7, 8, 9, 10, 11,
      12, 13, 17, 19, 20, 21, 22, 23, 24,
  };
  for (unsigned index = 0;
       index < sizeof(diagnosticRegisters) / sizeof(diagnosticRegisters[0]);
       index += 1) {
    unsigned registerIndex = diagnosticRegisters[index];
    cursor = AppBoxAppendSignalText(cursor, " x");
    if (registerIndex >= 10) {
      *cursor++ = (char)('0' + registerIndex / 10);
    }
    *cursor++ = (char)('0' + registerIndex % 10);
    *cursor++ = '=';
    cursor = AppBoxAppendSignalHex(
        cursor, context->uc_mcontext->__ss.__x[registerIndex]);
  }
  cursor = AppBoxAppendSignalText(cursor, " x25=");
  cursor = AppBoxAppendSignalHex(cursor, context->uc_mcontext->__ss.__x[25]);
  cursor = AppBoxAppendSignalText(cursor, " x26=");
  cursor = AppBoxAppendSignalHex(cursor, context->uc_mcontext->__ss.__x[26]);
  cursor = AppBoxAppendSignalText(cursor, " x27=");
  cursor = AppBoxAppendSignalHex(cursor, context->uc_mcontext->__ss.__x[27]);
  cursor = AppBoxAppendSignalText(cursor, " x28=");
  cursor = AppBoxAppendSignalHex(cursor, context->uc_mcontext->__ss.__x[28]);
  if (AppBoxDiagnosticWatchArmed && AppBoxDiagnosticWatchGuestState != 0) {
    const uintptr_t *watchedGuestRegisters =
        (const uintptr_t *)(AppBoxDiagnosticWatchGuestState + 0x40);
    cursor = AppBoxAppendSignalText(cursor, " watch_address=");
    cursor = AppBoxAppendSignalHex(cursor, AppBoxDiagnosticWatchAddress);
    for (unsigned guestIndex = 0; guestIndex < 8; guestIndex += 1) {
      cursor = AppBoxAppendSignalText(cursor, " watch_guest_x");
      *cursor++ = (char)('0' + guestIndex);
      *cursor++ = '=';
      cursor = AppBoxAppendSignalHex(
          cursor, watchedGuestRegisters[guestIndex]);
    }
    cursor = AppBoxAppendSignalText(cursor, " watch_guest_x30=");
    cursor = AppBoxAppendSignalHex(cursor, watchedGuestRegisters[30]);
    cursor = AppBoxAppendSignalText(cursor, " watch_guest_sp=");
    cursor = AppBoxAppendSignalHex(cursor, watchedGuestRegisters[31]);
    cursor = AppBoxAppendSignalText(cursor, " watch_guest_pc=");
    cursor = AppBoxAppendSignalHex(cursor, watchedGuestRegisters[32]);
  }
  if (adversarysOffset == 0x0088BC18 ||
      adversarysOffset == 0x0088BC70) {
    uintptr_t guestState = context->uc_mcontext->__ss.__x[14];
    const uintptr_t *guestRegisters =
        (const uintptr_t *)(guestState + 0x40);
    cursor = AppBoxAppendSignalText(cursor, " state=");
    cursor = AppBoxAppendSignalHex(cursor, guestState);
    cursor = AppBoxAppendSignalText(cursor, " guest_x0=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[0]);
    cursor = AppBoxAppendSignalText(cursor, " guest_x28=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[28]);
    cursor = AppBoxAppendSignalText(cursor, " guest_x29=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[29]);
    cursor = AppBoxAppendSignalText(cursor, " guest_x30=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[30]);
    cursor = AppBoxAppendSignalText(cursor, " guest_138=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[31]);
    cursor = AppBoxAppendSignalText(cursor, " guest_sp=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[32]);
    uintptr_t guestStack = guestRegisters[31];
    cursor = AppBoxAppendSignalText(cursor, " stack_word=");
    cursor = AppBoxAppendSignalHex(cursor, *(const uintptr_t *)guestStack);
  }
  if (adversarysOffset == 0x0088BC00) {
    const uintptr_t *guestRegisters =
        (const uintptr_t *)context->uc_mcontext->__ss.__x[11];
    cursor = AppBoxAppendSignalText(cursor, " guest_x0=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[0]);
    cursor = AppBoxAppendSignalText(cursor, " guest_x1=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[1]);
    cursor = AppBoxAppendSignalText(cursor, " guest_x28=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[28]);
    cursor = AppBoxAppendSignalText(cursor, " guest_x29=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[29]);
    cursor = AppBoxAppendSignalText(cursor, " guest_x30=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[30]);
    cursor = AppBoxAppendSignalText(cursor, " guest_sp=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[31]);
    cursor = AppBoxAppendSignalText(cursor, " guest_pc=");
    cursor = AppBoxAppendSignalHex(cursor, guestRegisters[32]);
  }
  uintptr_t runtimeObject = context->uc_mcontext->__ss.__x[0];
  if (pc == AppBoxDiagnosticAdversarysBase + 0x00008D38 &&
      runtimeObject != 0) {
    const uintptr_t *imageFields =
        (const uintptr_t *)(runtimeObject + 0xE0);
    cursor = AppBoxAppendSignalText(cursor, " image_e0=");
    cursor = AppBoxAppendSignalHex(cursor, imageFields[0]);
    cursor = AppBoxAppendSignalText(cursor, " image_e8=");
    cursor = AppBoxAppendSignalHex(cursor, imageFields[1]);
    cursor = AppBoxAppendSignalText(cursor, " image_f0=");
    cursor = AppBoxAppendSignalHex(cursor, imageFields[2]);
    cursor = AppBoxAppendSignalText(cursor, " image_f8=");
    cursor = AppBoxAppendSignalHex(cursor, imageFields[3]);
  }
  uintptr_t framePointer = context->uc_mcontext->__ss.__fp;
  cursor = AppBoxAppendSignalText(cursor, " x29=");
  cursor = AppBoxAppendSignalHex(cursor, framePointer);
  uintptr_t stackPointer = context->uc_mcontext->__ss.__sp;
  for (unsigned frameIndex = 0; frameIndex < 16; frameIndex += 1) {
    if (
        framePointer < stackPointer ||
        framePointer + 16 < framePointer ||
        framePointer + 16 > stackPointer + 0x400000 ||
        (framePointer & (sizeof(uintptr_t) - 1)) != 0
    ) {
      break;
    }
    const uintptr_t *frame = (const uintptr_t *)framePointer;
    uintptr_t previousFrame = frame[0];
    uintptr_t returnAddress = frame[1];
    cursor = AppBoxAppendSignalText(cursor, " frame");
    if (frameIndex >= 10) {
      *cursor++ = (char)('0' + frameIndex / 10);
    }
    *cursor++ = (char)('0' + frameIndex % 10);
    *cursor++ = '=';
    cursor = AppBoxAppendSignalHex(cursor, returnAddress);
    if (previousFrame <= framePointer) {
      break;
    }
    framePointer = previousFrame;
  }
  cursor = AppBoxAppendSignalText(cursor, " nivm_base=");
  uintptr_t nivmBase = 0;
  if (AppBoxDiagnosticAdversarysBase != 0) {
    nivmBase = *(const uintptr_t *)(AppBoxDiagnosticAdversarysBase + 0x62DE748);
  }
  cursor = AppBoxAppendSignalHex(cursor, nivmBase);
  *cursor++ = '\n';
  size_t length = (size_t)(cursor - buffer);
  write(STDERR_FILENO, buffer, length);
  if (AppBoxDiagnosticSignalFile >= 0) {
    write(AppBoxDiagnosticSignalFile, buffer, length);
  }
  _exit(128 + signalNumber);
}

static void AppBoxInstallDiagnosticSignalHandler(void) {
  Dl_info imageInfo = {0};
  if (AppBoxAdversarysOpen != NULL &&
      dladdr((void *)AppBoxAdversarysOpen, &imageInfo) != 0) {
    AppBoxDiagnosticAdversarysBase = (uintptr_t)imageInfo.dli_fbase;
  }
  AppBoxDiagnosticDispatchOnceArmed =
      [NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-dispatch-once"];
  NSURL *documentsURL = [NSFileManager.defaultManager
      URLsForDirectory:NSDocumentDirectory
      inDomains:NSUserDomainMask].lastObject;
  NSURL *signalURL =
      [documentsURL URLByAppendingPathComponent:@"appbox-runtime-signal.log"];
  if (AppBoxDiagnosticSignalFile >= 0) {
    close(AppBoxDiagnosticSignalFile);
  }
  AppBoxDiagnosticSignalFile = open(signalURL.fileSystemRepresentation,
                                    O_CREAT | O_WRONLY | O_TRUNC, 0600);
  struct sigaction action = {0};
  action.sa_sigaction = AppBoxDiagnosticSignalHandler;
  action.sa_flags = SA_SIGINFO;
  sigemptyset(&action.sa_mask);
  sigaction(SIGILL, &action, NULL);
  sigaction(SIGTRAP, &action, NULL);
  sigaction(SIGSEGV, &action, NULL);
  sigaction(SIGBUS, &action, NULL);
}

static void AppBoxLogDiagnosticMemory(NSString *stage) {
  task_vm_info_data_t info = {0};
  mach_msg_type_number_t count = TASK_VM_INFO_COUNT;
  kern_return_t result = task_info(
      mach_task_self(), TASK_VM_INFO, (task_info_t)&info, &count);
  NSLog(@"APPBOX_DIAGNOSTIC_MEMORY stage=%@ kr=%d footprint=%llu "
         "resident=%llu virtual=%llu peak=%llu",
        stage, result, (unsigned long long)info.phys_footprint,
        (unsigned long long)info.resident_size,
        (unsigned long long)info.virtual_size,
        (unsigned long long)info.resident_size_peak);
}

static void AppBoxDiagnosticSampleHandler(int signalNumber,
                                          siginfo_t *signalInfo,
                                          void *rawContext) {
  (void)signalNumber;
  (void)signalInfo;
  ucontext_t *context = (ucontext_t *)rawContext;
  uintptr_t pc = context->uc_mcontext->__ss.__pc;
  uintptr_t runtimeOffset = pc - AppBoxDiagnosticAdversarysBase;
  uintptr_t fuelCursor = context->uc_mcontext->__ss.__x[28];
  if (AppBoxDiagnosticSampleCount >= AppBoxDiagnosticSampleLimit ||
      AppBoxDiagnosticAdversarysBase == 0 ||
      runtimeOffset < 0x20000 || runtimeOffset >= 0x6258000 ||
      fuelCursor < 0x100000000) {
    return;
  }
  AppBoxDiagnosticSampleCount += 1;
  const uintptr_t *fuel = (const uintptr_t *)fuelCursor;
  char buffer[1024];
  char *cursor = AppBoxAppendSignalText(
      buffer, "APPBOX_DIAGNOSTIC_SAMPLE handler=");
  cursor = AppBoxAppendSignalHex(cursor, runtimeOffset);
  cursor = AppBoxAppendSignalText(cursor, " fuel_cursor=");
  cursor = AppBoxAppendSignalHex(cursor, fuelCursor);
  cursor = AppBoxAppendSignalText(cursor, " q-2=");
  cursor = AppBoxAppendSignalHex(cursor, fuel[-2]);
  cursor = AppBoxAppendSignalText(cursor, " q-1=");
  cursor = AppBoxAppendSignalHex(cursor, fuel[-1]);
  cursor = AppBoxAppendSignalText(cursor, " q0=");
  cursor = AppBoxAppendSignalHex(cursor, fuel[0]);
  cursor = AppBoxAppendSignalText(cursor, " q1=");
  cursor = AppBoxAppendSignalHex(cursor, fuel[1]);
  *cursor++ = '\n';
  write(STDERR_FILENO, buffer, (size_t)(cursor - buffer));
}

static void AppBoxInstallDiagnosticSampler(void) {
  struct sigaction action = {0};
  action.sa_sigaction = AppBoxDiagnosticSampleHandler;
  action.sa_flags = SA_SIGINFO | SA_RESTART;
  sigemptyset(&action.sa_mask);
  sigaction(SIGPROF, &action, NULL);
  struct itimerval timer = {0};
  timer.it_value.tv_usec = 100000;
  timer.it_interval.tv_usec = 100000;
  setitimer(ITIMER_PROF, &timer, NULL);
}

static void AppBoxSampleAdversarysThreads(void) {
  thread_act_array_t threads = NULL;
  mach_msg_type_number_t threadCount = 0;
  if (task_threads(mach_task_self(), &threads, &threadCount) != KERN_SUCCESS) {
    return;
  }
  mach_port_t samplerThread = mach_thread_self();
  for (mach_msg_type_number_t index = 0;
       index < threadCount &&
           AppBoxDiagnosticSampleCount < AppBoxDiagnosticSampleLimit;
       index += 1) {
    thread_t thread = threads[index];
    if (thread == samplerThread || thread_suspend(thread) != KERN_SUCCESS) {
      continue;
    }
    arm_thread_state64_t state = {0};
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
    kern_return_t result = thread_get_state(
        thread, ARM_THREAD_STATE64, (thread_state_t)&state, &stateCount);
    uintptr_t pc = result == KERN_SUCCESS ? arm_thread_state64_get_pc(state) : 0;
    uintptr_t lr = result == KERN_SUCCESS ? arm_thread_state64_get_lr(state) : 0;
    uintptr_t runtimeOffset = pc - AppBoxDiagnosticAdversarysBase;
    uintptr_t fuelCursor = result == KERN_SUCCESS
        ? state.__x[28]
        : 0;
    uintptr_t runtimeRegister = result == KERN_SUCCESS
        ? state.__x[26]
        : 0;
    uintptr_t qMinus2 = 0;
    uintptr_t qMinus1 = 0;
    uintptr_t qZero = 0;
    uintptr_t qOne = 0;
    BOOL shouldLog = result == KERN_SUCCESS &&
        AppBoxDiagnosticAdversarysBase != 0 &&
        runtimeRegister == AppBoxDiagnosticAdversarysBase &&
        fuelCursor >= 0x100000000;
    if (shouldLog) {
      const uintptr_t *fuel = (const uintptr_t *)fuelCursor;
      qMinus2 = fuel[-2];
      qMinus1 = fuel[-1];
      qZero = fuel[0];
      qOne = fuel[1];
    }
    thread_resume(thread);
    if (!shouldLog) {
      continue;
    }
    AppBoxDiagnosticSampleCount += 1;
    char buffer[1024];
    char *cursor = AppBoxAppendSignalText(
        buffer, "APPBOX_DIAGNOSTIC_THREAD_SAMPLE pc=");
    cursor = AppBoxAppendSignalHex(cursor, pc);
    cursor = AppBoxAppendSignalText(cursor, " lr=");
    cursor = AppBoxAppendSignalHex(cursor, lr);
    cursor = AppBoxAppendSignalText(cursor, " handler=");
    cursor = AppBoxAppendSignalHex(cursor, runtimeOffset);
    cursor = AppBoxAppendSignalText(cursor, " fuel_cursor=");
    cursor = AppBoxAppendSignalHex(cursor, fuelCursor);
    cursor = AppBoxAppendSignalText(cursor, " q-2=");
    cursor = AppBoxAppendSignalHex(cursor, qMinus2);
    cursor = AppBoxAppendSignalText(cursor, " q-1=");
    cursor = AppBoxAppendSignalHex(cursor, qMinus1);
    cursor = AppBoxAppendSignalText(cursor, " q0=");
    cursor = AppBoxAppendSignalHex(cursor, qZero);
    cursor = AppBoxAppendSignalText(cursor, " q1=");
    cursor = AppBoxAppendSignalHex(cursor, qOne);
    *cursor++ = '\n';
    write(STDERR_FILENO, buffer, (size_t)(cursor - buffer));
  }
  mach_port_deallocate(mach_task_self(), samplerThread);
  vm_deallocate(mach_task_self(), (vm_address_t)threads,
                threadCount * sizeof(thread_t));
}

static unsigned int AppBoxSampleAdversarysThreadsToFile(FILE *output,
                                                         unsigned int ordinal) {
  thread_act_array_t threads = NULL;
  mach_msg_type_number_t threadCount = 0;
  if (task_threads(mach_task_self(), &threads, &threadCount) != KERN_SUCCESS) {
    return 0;
  }
  mach_port_t samplerThread = mach_thread_self();
  unsigned int hits = 0;
  for (mach_msg_type_number_t index = 0; index < threadCount; index += 1) {
    thread_t thread = threads[index];
    if (thread == samplerThread || thread_suspend(thread) != KERN_SUCCESS) {
      continue;
    }
    arm_thread_state64_t state = {0};
    mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
    kern_return_t stateResult = thread_get_state(
        thread, ARM_THREAD_STATE64, (thread_state_t)&state, &stateCount);
    thread_resume(thread);
    if (stateResult != KERN_SUCCESS) {
      continue;
    }
    uintptr_t pc = arm_thread_state64_get_pc(state);
    uintptr_t runtimeRegister = state.__x[26];
    uintptr_t fuelCursor = state.__x[28];
    uintptr_t imageBase = state.__x[17];
    uintptr_t guestRegisterBase = state.__x[11];
    uintptr_t hostX0 = state.__x[0];
    uintptr_t guestX8 = 0;
    uintptr_t guestX19 = 0;
    uint64_t flutterConstProbe[2] = {0, 0};
    vm_size_t flutterConstProbeSize = 0;
    kern_return_t flutterConstProbeResult = KERN_INVALID_ADDRESS;
    if (AppBoxDiagnosticAdversarysBase == 0 ||
        runtimeRegister != AppBoxDiagnosticAdversarysBase ||
        fuelCursor < 0x100000000) {
      continue;
    }
    if (guestRegisterBase >= 0x100000000) {
      const uintptr_t *guestRegisters =
          (const uintptr_t *)guestRegisterBase;
      guestX8 = guestRegisters[8];
      guestX19 = guestRegisters[19];
    }
    if (imageBase >= 0x100000000) {
      flutterConstProbeResult = vm_read_overwrite(
          mach_task_self(), (vm_address_t)(imageBase + 0x776fd0),
          sizeof(flutterConstProbe),
          (vm_address_t)flutterConstProbe,
          &flutterConstProbeSize);
    }
    const uintptr_t *fuel = (const uintptr_t *)fuelCursor;
    fprintf(output,
            "%u 0x%llx 0x%llx 0x%llx 0x%llx 0x%llx 0x%llx %u "
            "image=0x%llx regs=0x%llx host_x0=0x%llx "
            "guest_x8=0x%llx guest_x19=0x%llx "
            "flutter_const_kr=%d size=0x%llx data=0x%llx,0x%llx\n",
            ordinal, (unsigned long long)pc,
            (unsigned long long)fuelCursor,
            (unsigned long long)fuel[-2],
            (unsigned long long)fuel[-1],
            (unsigned long long)fuel[0],
            (unsigned long long)fuel[1], thread,
            (unsigned long long)imageBase,
            (unsigned long long)guestRegisterBase,
            (unsigned long long)hostX0,
            (unsigned long long)guestX8,
            (unsigned long long)guestX19,
            flutterConstProbeResult,
            (unsigned long long)flutterConstProbeSize,
            (unsigned long long)flutterConstProbe[0],
            (unsigned long long)flutterConstProbe[1]);
    hits += 1;
  }
  mach_port_deallocate(mach_task_self(), samplerThread);
  vm_deallocate(mach_task_self(), (vm_address_t)threads,
                threadCount * sizeof(thread_t));
  return hits;
}

static void AppBoxStartDiagnosticFileBurst(NSString *reason) {
  if (![NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-result-file-burst"] ||
      !__sync_bool_compare_and_swap(&AppBoxDiagnosticFileBurstStarted, 0, 1)) {
    return;
  }
  NSString *reasonCopy = [reason copy];
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INITIATED, 0), ^{
    @autoreleasepool {
      NSURL *documentsURL = [NSFileManager.defaultManager
          URLsForDirectory:NSDocumentDirectory
          inDomains:NSUserDomainMask].lastObject;
      NSURL *outputURL =
          [documentsURL URLByAppendingPathComponent:@"appbox-runtime-fuel.log"];
      FILE *output = fopen(outputURL.fileSystemRepresentation, "w");
      if (output == NULL) {
        NSLog(@"APPBOX_DIAGNOSTIC_FILE_BURST open_failed path=%@ errno=%d",
              outputURL.path, errno);
        return;
      }
      // The guest runtime may terminate the process with _exit(), which skips
      // stdio flushing.  Keep every sampled fuel cursor durable as it is
      // collected so the last translated block remains available afterward.
      setvbuf(output, NULL, _IONBF, 0);
      fprintf(output, "ADVERSARYS_BASE 0x%llx REASON %s\n",
              (unsigned long long)AppBoxDiagnosticAdversarysBase,
              reasonCopy.UTF8String ?: "");
      unsigned int hits = 0;
      for (unsigned int ordinal = 0; ordinal < 14000; ordinal += 1) {
        hits += AppBoxSampleAdversarysThreadsToFile(output, ordinal);
        usleep(500);
      }
      fprintf(output, "DONE samples=14000 hits=%u\n", hits);
      fclose(output);
      NSLog(@"APPBOX_DIAGNOSTIC_FILE_BURST end hits=%u path=%@", hits,
            outputURL.path);
    }
  });
}

static void AppBoxStartDiagnosticFocusedBurst(void) {
  if (!__sync_bool_compare_and_swap(&AppBoxDiagnosticFocusedBurstStarted,
                                    0, 1)) {
    return;
  }
  thread_t targetThread = mach_thread_self();
  dispatch_semaphore_t ready = dispatch_semaphore_create(0);
  dispatch_async(dispatch_get_global_queue(QOS_CLASS_USER_INTERACTIVE, 0), ^{
    @autoreleasepool {
      NSURL *documentsURL = [NSFileManager.defaultManager
          URLsForDirectory:NSDocumentDirectory
          inDomains:NSUserDomainMask].lastObject;
      NSURL *outputURL = [documentsURL
          URLByAppendingPathComponent:@"appbox-runtime-focused.log"];
      FILE *output = fopen(outputURL.fileSystemRepresentation, "w");
      if (output == NULL) {
        dispatch_semaphore_signal(ready);
        mach_port_deallocate(mach_task_self(), targetThread);
        return;
      }
      setvbuf(output, NULL, _IONBF, 0);
      fprintf(output, "ADVERSARYS_BASE 0x%llx THREAD %u\n",
              (unsigned long long)AppBoxDiagnosticAdversarysBase,
              targetThread);
      dispatch_semaphore_signal(ready);
      // Tianya can terminate during the first translated instructions after
      // guest_main_start.  Begin sampling immediately so the durable trace
      // retains the last main-thread Fuel cursor before an uncatchable kill.
      usleep(0);
      unsigned int hits = 0;
      for (unsigned int ordinal = 0;
           ordinal < 600000 && hits < 60000;
           ordinal++) {
        arm_thread_state64_t state = {0};
        mach_msg_type_number_t stateCount = ARM_THREAD_STATE64_COUNT;
        if (thread_suspend(targetThread) != KERN_SUCCESS) {
          continue;
        }
        kern_return_t stateResult = thread_get_state(
            targetThread, ARM_THREAD_STATE64, (thread_state_t)&state,
            &stateCount);
        thread_resume(targetThread);
        if (stateResult != KERN_SUCCESS) {
          continue;
        }
        uintptr_t pc = arm_thread_state64_get_pc(state);
        uintptr_t runtimeRegister = state.__x[26];
        uintptr_t fuelCursor = state.__x[28];
        if (AppBoxDiagnosticAdversarysBase == 0 ||
            runtimeRegister != AppBoxDiagnosticAdversarysBase ||
            fuelCursor < 0x100000000) {
          usleep(50);
          continue;
        }
        uintptr_t nivmBase = *(const uintptr_t *)(
            AppBoxDiagnosticAdversarysBase + 0x62DE748);
        fprintf(output,
                "%u pc=0x%llx fuel_cursor=0x%llx nivm_base=0x%llx\n",
                ordinal, (unsigned long long)pc,
                (unsigned long long)fuelCursor,
                (unsigned long long)nivmBase);
        hits++;
        usleep(100);
      }
      fprintf(output, "DONE attempts=600000 hits=%u\n", hits);
      fclose(output);
      mach_port_deallocate(mach_task_self(), targetThread);
      NSLog(@"APPBOX_DIAGNOSTIC_FOCUSED end hits=%u path=%@", hits,
            outputURL.path);
    }
  });
  dispatch_semaphore_wait(ready,
                          dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC));
}

static void AppBoxScheduleDiagnosticThreadSampler(void) {
  dispatch_queue_t queue = dispatch_get_global_queue(QOS_CLASS_UTILITY, 0);
  dispatch_source_t timer = dispatch_source_create(
      DISPATCH_SOURCE_TYPE_TIMER, 0, 0, queue);
  dispatch_source_set_timer(
      timer, dispatch_time(DISPATCH_TIME_NOW, 500 * NSEC_PER_MSEC),
      10 * NSEC_PER_MSEC, 2 * NSEC_PER_MSEC);
  dispatch_source_set_event_handler(timer, ^{
    AppBoxSampleAdversarysThreads();
    if (AppBoxDiagnosticSampleCount >= AppBoxDiagnosticSampleLimit) {
      dispatch_source_cancel(timer);
    }
  });
  dispatch_resume(timer);
}

static NSString *const AppBoxGuestModeKey = @"AppBoxPlayBoxGuestMode";
static NSString *const AppBoxGuestLaunchTokenKey = @"AppBoxPlayBoxGuestLaunchToken";
static NSString *const AppBoxGuestBundleKey = @"AppBoxPlayBoxGuestBundle";
static NSString *const AppBoxGuestExecutableKey = @"AppBoxPlayBoxGuestExecutable";
static NSString *const AppBoxGuestNIVMKey = @"AppBoxPlayBoxGuestNIVM";
static NSString *const AppBoxRuntimeKindKey = @"AppBoxGuestRuntimeKind";
static NSString *const AppBoxRuntimeLaunchTokenKey = @"AppBoxGuestLaunchToken";
static NSString *const AppBoxPlayBoxContinuationMarker =
    @"AppBoxTest/playbox-relaunch-continuation";

static NSURL *AppBoxPlayBoxContinuationMarkerURL(void) {
  NSURL *documentsURL = [NSFileManager.defaultManager
      URLsForDirectory:NSDocumentDirectory
      inDomains:NSUserDomainMask].lastObject;
  return [documentsURL URLByAppendingPathComponent:
      AppBoxPlayBoxContinuationMarker];
}

static BOOL AppBoxConsumeFreshPlayBoxContinuationMarker(void) {
  NSURL *markerURL = AppBoxPlayBoxContinuationMarkerURL();
  NSDictionary<NSFileAttributeKey, id> *attributes =
      [NSFileManager.defaultManager attributesOfItemAtPath:markerURL.path
                                                    error:nil];
  NSDate *modified = attributes[NSFileModificationDate];
  if (modified == nil) {
    return NO;
  }
  NSTimeInterval age = -modified.timeIntervalSinceNow;
  [NSFileManager.defaultManager removeItemAtURL:markerURL error:nil];
  if (age < 0 || age > 180) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME continuation_ignored age=%.1f", age);
    return NO;
  }
  NSLog(@"APPBOX_PLAYBOX_RUNTIME continuation_consumed age=%.1f", age);
  return YES;
}

@class AppBoxGuestFloatingControl;

@interface AppBoxFloatingMenuView : UIView
@property(nonatomic, strong) UIView *coverView;
@property(nonatomic, strong) UIControl *actionButton;
@property(nonatomic, strong) UIImageView *actionIconView;
@property(nonatomic, strong) UILabel *actionTitleLabel;
@property(nonatomic, weak) AppBoxGuestFloatingControl *sourceControl;
- (void)displayFromControl:(AppBoxGuestFloatingControl *)control
                    inView:(UIView *)container
                  animated:(BOOL)animated;
- (void)hideAnimated:(BOOL)animated;
@end

@interface AppBoxGuestFloatingControl : UIControl
@property(nonatomic, strong) UIImageView *iconView;
- (void)showMenuAnimated:(BOOL)animated;
@end

static AppBoxGuestFloatingControl *AppBoxGuestFloatingView;
static AppBoxFloatingMenuView *AppBoxGuestFloatingMenuView;
static BOOL AppBoxFloatingReturnInFlight;
static const CGFloat AppBoxFloatingActionSize = 82;

static NSBundle *AppBoxPlayBoxFloatingBundle(void) {
  NSBundle *hostBundle = AppBoxHostBundle;
  if (hostBundle == nil) {
    hostBundle = [NSBundle bundleForClass:AppBoxGuestFloatingControl.class];
  }
  NSString *path = [hostBundle.bundlePath
      stringByAppendingPathComponent:
          @"Frameworks/PBPlayerKit.framework/Floating.bundle"];
  return [NSBundle bundleWithPath:path];
}

static UIImage *AppBoxFloatingImage(NSString *name) {
  return [UIImage imageNamed:name
                    inBundle:AppBoxPlayBoxFloatingBundle()
       compatibleWithTraitCollection:nil];
}

static NSString *AppBoxFloatingLocalizedString(NSString *key,
                                                NSString *fallback) {
  NSBundle *bundle = AppBoxPlayBoxFloatingBundle();
  NSString *value = [bundle localizedStringForKey:key
                                             value:fallback
                                             table:@"PBPlayerFramework"];
  return value.length > 0 ? value : fallback;
}

static void AppBoxReturnToSandbox(void) {
  if (AppBoxFloatingReturnInFlight) {
    return;
  }
  AppBoxFloatingReturnInFlight = YES;
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  [defaults removeObjectForKey:AppBoxRuntimeLaunchTokenKey];
  [defaults removeObjectForKey:AppBoxGuestLaunchTokenKey];
  [defaults removeObjectForKey:AppBoxGuestModeKey];
  [defaults synchronize];
  [NSFileManager.defaultManager
      removeItemAtURL:AppBoxPlayBoxContinuationMarkerURL()
                error:nil];

  NSURL *relaunchURL = [NSURL URLWithString:
      @"appbox://playbox.guestapp.relaunch"];
  NSLog(@"APPBOX_FLOATING_RETURN requested url=%@", relaunchURL);
  void (^completion)(BOOL) = ^(BOOL accepted) {
    NSLog(@"APPBOX_FLOATING_RETURN accepted=%d", accepted);
    if (!accepted) {
      AppBoxFloatingReturnInFlight = NO;
      return;
    }
    [UIApplication.sharedApplication performSelector:
        NSSelectorFromString(@"suspend")];
    exit(0);
  };
  [UIApplication.sharedApplication openURL:relaunchURL
                                   options:@{}
                         completionHandler:completion];
  [UIApplication.sharedApplication openURL:relaunchURL
                                   options:@{}
                         completionHandler:completion];
}

@implementation AppBoxFloatingMenuView

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self == nil) {
    return nil;
  }
  self.accessibilityViewIsModal = YES;

  _coverView = [[UIView alloc] initWithFrame:self.bounds];
  _coverView.autoresizingMask = UIViewAutoresizingFlexibleWidth |
      UIViewAutoresizingFlexibleHeight;
  // PlayBox deliberately keeps the cover visually transparent while using it
  // to intercept taps outside the menu (alpha 0.01 in FloatingCore).
  _coverView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.01];
  UITapGestureRecognizer *dismissTap = [[UITapGestureRecognizer alloc]
      initWithTarget:self action:@selector(handleCoverTap)];
  [_coverView addGestureRecognizer:dismissTap];
  [self addSubview:_coverView];

  _actionButton = [[UIControl alloc]
      initWithFrame:CGRectMake(0, 0, AppBoxFloatingActionSize,
                               AppBoxFloatingActionSize)];
  _actionButton.accessibilityIdentifier = @"appbox.return-to-sandbox.action";
  _actionButton.accessibilityLabel = AppBoxFloatingLocalizedString(
      @"floating_back_app_title", @"返回沙盒");
  _actionButton.backgroundColor =
      [UIColor.blackColor colorWithAlphaComponent:0.84];
  _actionButton.layer.cornerRadius = 11;
  _actionButton.layer.borderWidth = 0.5;
  _actionButton.layer.borderColor =
      [UIColor.whiteColor colorWithAlphaComponent:0.10].CGColor;
  [_actionButton addTarget:self
                    action:@selector(handleActionTap)
          forControlEvents:UIControlEventTouchUpInside];
  [self addSubview:_actionButton];

  _actionIconView = [[UIImageView alloc] initWithImage:
      AppBoxFloatingImage(@"cscb_floating_back_icon")];
  _actionIconView.contentMode = UIViewContentModeScaleAspectFit;
  _actionIconView.userInteractionEnabled = NO;
  [_actionButton addSubview:_actionIconView];

  _actionTitleLabel = [[UILabel alloc] initWithFrame:CGRectZero];
  _actionTitleLabel.text = AppBoxFloatingLocalizedString(
      @"floating_back_app_title", @"返回沙盒");
  _actionTitleLabel.textColor = UIColor.whiteColor;
  _actionTitleLabel.font = [UIFont systemFontOfSize:12
                                            weight:UIFontWeightRegular];
  _actionTitleLabel.textAlignment = NSTextAlignmentCenter;
  _actionTitleLabel.userInteractionEnabled = NO;
  [_actionButton addSubview:_actionTitleLabel];
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  self.coverView.frame = self.bounds;
  self.actionIconView.frame = CGRectMake(27, 13, 28, 28);
  self.actionTitleLabel.frame = CGRectMake(4, 46, 74, 17);
}

- (CGRect)targetFrameForControl:(AppBoxGuestFloatingControl *)control
                      container:(UIView *)container {
  CGRect sourceFrame = [control.superview convertRect:control.frame
                                                toView:container];
  CGFloat x = CGRectGetMidX(sourceFrame) - AppBoxFloatingActionSize / 2.0;
  CGFloat y = CGRectGetMidY(sourceFrame) - AppBoxFloatingActionSize / 2.0;
  x = MIN(MAX(x, 16), CGRectGetWidth(container.bounds) -
                              AppBoxFloatingActionSize - 16);
  return CGRectMake(x, y, AppBoxFloatingActionSize,
                    AppBoxFloatingActionSize);
}

- (void)displayFromControl:(AppBoxGuestFloatingControl *)control
                    inView:(UIView *)container
                  animated:(BOOL)animated {
  self.sourceControl = control;
  self.frame = container.bounds;
  self.autoresizingMask = UIViewAutoresizingFlexibleWidth |
      UIViewAutoresizingFlexibleHeight;
  [container addSubview:self];

  CGRect sourceFrame = [control.superview convertRect:control.frame
                                                toView:self];
  CGRect targetFrame = [self targetFrameForControl:control container:self];
  self.actionButton.frame = targetFrame;
  [self setNeedsLayout];
  [self layoutIfNeeded];
  if (!animated) {
    self.actionButton.transform = CGAffineTransformIdentity;
    return;
  }

  CGFloat sourceScale = CGRectGetWidth(sourceFrame) /
      CGRectGetWidth(targetFrame);
  CGAffineTransform scale = CGAffineTransformMakeScale(sourceScale,
                                                       sourceScale);
  CGFloat dx = CGRectGetMidX(sourceFrame) - CGRectGetMidX(targetFrame);
  CGFloat dy = CGRectGetMidY(sourceFrame) - CGRectGetMidY(targetFrame);
  self.actionButton.transform = CGAffineTransformConcat(
      scale, CGAffineTransformMakeTranslation(dx / sourceScale,
                                              dy / sourceScale));
  [UIView animateWithDuration:0.25 animations:^{
    self.actionButton.transform = CGAffineTransformIdentity;
  }];
}

- (void)hideAnimated:(BOOL)animated {
  AppBoxGuestFloatingControl *control = self.sourceControl;
  if (!animated || control.superview == nil) {
    [self removeFromSuperview];
    AppBoxGuestFloatingMenuView = nil;
    return;
  }
  CGRect sourceFrame = [control.superview convertRect:control.frame
                                                toView:self];
  CGRect targetFrame = self.actionButton.frame;
  CGFloat sourceScale = CGRectGetWidth(sourceFrame) /
      CGRectGetWidth(targetFrame);
  CGFloat dx = CGRectGetMidX(sourceFrame) - CGRectGetMidX(targetFrame);
  CGFloat dy = CGRectGetMidY(sourceFrame) - CGRectGetMidY(targetFrame);
  CGAffineTransform transform = CGAffineTransformConcat(
      CGAffineTransformMakeScale(sourceScale, sourceScale),
      CGAffineTransformMakeTranslation(dx / sourceScale,
                                       dy / sourceScale));
  [UIView animateWithDuration:0.25
                   animations:^{ self.actionButton.transform = transform; }
                   completion:^(__unused BOOL finished) {
    [self removeFromSuperview];
    AppBoxGuestFloatingMenuView = nil;
  }];
}

- (void)handleCoverTap {
  [self hideAnimated:YES];
}

- (void)handleActionTap {
  AppBoxReturnToSandbox();
}

@end

@implementation AppBoxGuestFloatingControl

- (instancetype)initWithFrame:(CGRect)frame {
  self = [super initWithFrame:frame];
  if (self == nil) {
    return nil;
  }
  self.accessibilityIdentifier = @"appbox.return-to-sandbox";
  self.accessibilityLabel = AppBoxFloatingLocalizedString(
      @"floating_back_app_title", @"返回沙盒");

  _iconView = [[UIImageView alloc] initWithFrame:CGRectZero];
  _iconView.contentMode = UIViewContentModeScaleAspectFit;
  _iconView.image = AppBoxFloatingImage(@"cscb_floating_icon");
  _iconView.highlightedImage =
      AppBoxFloatingImage(@"cscb_floating_icon_highlight");
  if (_iconView.image == nil) {
    _iconView.image = [UIImage systemImageNamed:@"shippingbox.fill"];
    _iconView.tintColor = UIColor.whiteColor;
    _iconView.backgroundColor = [UIColor colorWithRed:0.16
                                                green:0.23
                                                 blue:0.43
                                                alpha:0.96];
    _iconView.layer.cornerRadius = 30;
  }
  _iconView.userInteractionEnabled = NO;
  [self addSubview:_iconView];

  [self addTarget:self
           action:@selector(handleTap)
 forControlEvents:UIControlEventTouchUpInside];
  UIPanGestureRecognizer *pan = [[UIPanGestureRecognizer alloc]
      initWithTarget:self action:@selector(handlePan:)];
  [self addGestureRecognizer:pan];
  return self;
}

- (void)layoutSubviews {
  [super layoutSubviews];
  self.iconView.frame = self.bounds;
}

- (void)setHighlighted:(BOOL)highlighted {
  [super setHighlighted:highlighted];
  self.iconView.highlighted = highlighted;
}

- (void)handleTap {
  [self showMenuAnimated:YES];
}

- (void)showMenuAnimated:(BOOL)animated {
  UIView *container = self.superview;
  if (container == nil || AppBoxGuestFloatingMenuView.superview != nil) {
    return;
  }
  AppBoxFloatingMenuView *menu = [[AppBoxFloatingMenuView alloc]
      initWithFrame:container.bounds];
  AppBoxGuestFloatingMenuView = menu;
  [menu displayFromControl:self inView:container animated:animated];
}

- (void)handlePan:(UIPanGestureRecognizer *)pan {
  UIView *container = self.superview;
  if (container == nil) {
    return;
  }
  CGPoint translation = [pan translationInView:container];
  self.center = CGPointMake(self.center.x + translation.x,
                            self.center.y + translation.y);
  [pan setTranslation:CGPointZero inView:container];
  if (pan.state != UIGestureRecognizerStateEnded &&
      pan.state != UIGestureRecognizerStateCancelled) {
    return;
  }
  UIEdgeInsets safe = container.safeAreaInsets;
  CGFloat halfWidth = CGRectGetWidth(self.bounds) / 2.0;
  CGFloat halfHeight = CGRectGetHeight(self.bounds) / 2.0;
  CGFloat left = safe.left + 8 + halfWidth;
  CGFloat right = CGRectGetWidth(container.bounds) - safe.right - 8 - halfWidth;
  CGFloat top = safe.top + 18 + halfHeight;
  CGFloat bottom = CGRectGetHeight(container.bounds) - safe.bottom - 18 - halfHeight;
  CGPoint target = self.center;
  target.x = target.x < CGRectGetMidX(container.bounds) ? left : right;
  target.y = MIN(MAX(target.y, top), bottom);
  [UIView animateWithDuration:0.2 animations:^{ self.center = target; }];
}

@end

static void AppBoxInstallGuestFloatingControl(UIWindow *window) {
  if (window == nil) {
    return;
  }
  [AppBoxGuestFloatingMenuView removeFromSuperview];
  AppBoxGuestFloatingMenuView = nil;
  [AppBoxGuestFloatingView removeFromSuperview];
  CGFloat size = 60;
  UIEdgeInsets safe = window.safeAreaInsets;
  CGFloat x = CGRectGetWidth(window.bounds) - safe.right - size - 8;
  CGFloat y = MAX(safe.top + 82, CGRectGetHeight(window.bounds) * 0.48);
  y = MIN(y, CGRectGetHeight(window.bounds) - safe.bottom - size - 24);
  AppBoxGuestFloatingControl *control =
      [[AppBoxGuestFloatingControl alloc]
          initWithFrame:CGRectMake(x, y, size, size)];
  control.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin |
      UIViewAutoresizingFlexibleTopMargin;
  [window addSubview:control];
  [window bringSubviewToFront:control];
  AppBoxGuestFloatingView = control;
  NSLog(@"APPBOX_FLOATING_RETURN installed window=%@ asset=%d",
        NSStringFromClass(window.class), control.iconView.image != nil);
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-test-floating-return"]) {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                 (int64_t)(2.5 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
      [control showMenuAnimated:NO];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(4.0 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
        AppBoxReturnToSandbox();
      });
    });
  }
}

static void *AppBoxLoadFramework(NSString *name) {
  NSString *path = [NSBundle.mainBundle.privateFrameworksPath
      stringByAppendingPathComponent:[NSString stringWithFormat:@"%@.framework/%@", name, name]];
  void *handle = dlopen(path.fileSystemRepresentation, RTLD_NOW | RTLD_GLOBAL);
  if (handle == NULL) {
    NSLog(@"APPBOX_RUNTIME framework_load_failed name=%@ error=%s", name, dlerror());
  } else {
    NSLog(@"APPBOX_RUNTIME framework_loaded name=%@", name);
  }
  return handle;
}

static BOOL AppBoxLoadPlayBoxRuntime(void) {
  void *player = AppBoxLoadFramework(@"PBPlayerKit");
  void *runtime = AppBoxLoadFramework(@"adversarys");
  if (player == NULL || runtime == NULL) {
    return NO;
  }
  // Save the host Kiwi class before a guest with its own statically linked
  // class is loaded and Objective-C reports a duplicate name.
  AppBoxNativeKiwiClass = NSClassFromString(@"Kiwi");

  AppBoxNUDGuestHooksInit = dlsym(player, "NUDGuestHooksInit");
  AppBoxPBPlayerSetupApp = dlsym(
      player, "_$s11PBPlayerKit0aB3BoxV8setupAppyyFZ");
  AppBoxAdversarysOpen = dlsym(runtime, "adversarys_0_ex");
  AppBoxAdversarysOpenLoose = dlsym(runtime, "adversarys_0");
  AppBoxAdversarysSymbol = dlsym(runtime, "adversarys_1");
  AppBoxAdversarysError = dlsym(runtime, "adversarys_2");
  AppBoxAdversarysClass = dlsym(runtime, "adversarys_4");
  AppBoxAdversarysAbort = dlsym(runtime, "adversarys_b");
  AppBoxAdversarysHandler = dlsym(runtime, "adversarys_d");
  Dl_info runtimeInfo = {0};
  if (AppBoxAdversarysOpen != NULL &&
      dladdr((void *)AppBoxAdversarysOpen, &runtimeInfo) != 0) {
    AppBoxDiagnosticAdversarysBase = (uintptr_t)runtimeInfo.dli_fbase;
  }
  void *defaultMainLoop = dlsym(RTLD_DEFAULT, "AppBoxEnterGuestMainLoop");
  void *mainOnlyMainLoop = dlsym(RTLD_MAIN_ONLY, "AppBoxEnterGuestMainLoop");
  NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_main_loop_symbol default=%p main=%p",
        defaultMainLoop, mainOnlyMainLoop);
  return AppBoxNUDGuestHooksInit != NULL && AppBoxAdversarysOpen != NULL &&
      AppBoxAdversarysOpenLoose != NULL &&
      AppBoxAdversarysSymbol != NULL && AppBoxAdversarysError != NULL &&
      AppBoxAdversarysClass != NULL && AppBoxAdversarysAbort != NULL &&
      AppBoxAdversarysHandler != NULL;
}

static UITableView *AppBoxFindTableView(UIView *view) {
  if ([view isKindOfClass:UITableView.class]) {
    return (UITableView *)view;
  }
  for (UIView *subview in view.subviews) {
    UITableView *tableView = AppBoxFindTableView(subview);
    if (tableView != nil) {
      return tableView;
    }
  }
  return nil;
}

static void AppBoxCollectViewText(UIView *view,
                                  NSMutableArray<NSString *> *texts) {
  if ([view isKindOfClass:UILabel.class]) {
    NSString *text = ((UILabel *)view).text;
    if (text.length > 0) {
      [texts addObject:text];
    }
  }
  for (UIView *subview in view.subviews) {
    AppBoxCollectViewText(subview, texts);
  }
}

@interface AppBoxPlayBoxDeveloperDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@end

@implementation AppBoxPlayBoxDeveloperDelegate
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  if (!AppBoxLoadPlayBoxRuntime()) {
    NSLog(@"APPBOX_PLAYBOX_DEVELOPER boot_failed reason=runtime_load");
    return NO;
  }
  if (AppBoxPBPlayerSetupApp != NULL) {
    AppBoxPBPlayerSetupApp();
  }

  Class controllerClass =
      NSClassFromString(@"PBPlayerKit.DeveloperController");
  if (controllerClass == Nil) {
    controllerClass = NSClassFromString(
        @"_TtC11PBPlayerKit19DeveloperController");
  }
  if (controllerClass == Nil) {
    NSLog(@"APPBOX_PLAYBOX_DEVELOPER boot_failed reason=controller_missing");
    return NO;
  }

  UIViewController *controller = [[controllerClass alloc] init];
  UINavigationController *navigation =
      [[UINavigationController alloc] initWithRootViewController:controller];
  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = navigation;
  [self.window makeKeyAndVisible];
  NSLog(@"APPBOX_PLAYBOX_DEVELOPER ready controller=%@",
        NSStringFromClass(controllerClass));
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
    [controller loadViewIfNeeded];
    UITableView *tableView = AppBoxFindTableView(controller.view);
    if (tableView == nil) {
      NSLog(@"APPBOX_PLAYBOX_DEVELOPER table_missing");
      return;
    }
    NSInteger sectionCount = [tableView.dataSource
        numberOfSectionsInTableView:tableView];
    NSLog(@"APPBOX_PLAYBOX_DEVELOPER table sections=%ld",
          (long)sectionCount);
    for (NSInteger section = 0; section < sectionCount; section++) {
      NSInteger rowCount = [tableView.dataSource tableView:tableView
                                     numberOfRowsInSection:section];
      for (NSInteger row = 0; row < rowCount; row++) {
        NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row
                                                    inSection:section];
        UITableViewCell *cell = [tableView.dataSource tableView:tableView
                                         cellForRowAtIndexPath:indexPath];
        NSMutableArray<NSString *> *texts = NSMutableArray.array;
        AppBoxCollectViewText(cell, texts);
        NSLog(@"APPBOX_PLAYBOX_DEVELOPER row section=%ld row=%ld text=%@",
              (long)section, (long)row,
              [texts componentsJoinedByString:@" | "]);
      }
    }
    if ([NSProcessInfo.processInfo.arguments
            containsObject:@"--appbox-playbox-open-local-picker"]) {
      NSIndexPath *localAppRow = [NSIndexPath indexPathForRow:2 inSection:0];
      [tableView.delegate tableView:tableView
           didSelectRowAtIndexPath:localAppRow];
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW, NSEC_PER_SEC),
                     dispatch_get_main_queue(), ^{
        UIViewController *presented = navigation.presentedViewController;
        if (presented == nil) {
          presented = controller.presentedViewController;
        }
        NSLog(@"APPBOX_PLAYBOX_DEVELOPER local_picker presented=%@ delegate=%@",
              NSStringFromClass(presented.class),
              NSStringFromClass(((UIDocumentPickerViewController *)presented)
                                    .delegate.class));
      });
    }
  });
  return YES;
}
@end

static void AppBoxRegisterFlutterPlugin(id engine, NSString *framework,
                                        NSString *className,
                                        NSString *pluginKey) {
  if (AppBoxLoadFramework(framework) == NULL) {
    return;
  }
  Class pluginClass = NSClassFromString(className);
  if (pluginClass == Nil) {
    pluginClass = NSClassFromString(
        [NSString stringWithFormat:@"%@.%@", framework, className]);
  }
  SEL registerSelector = NSSelectorFromString(@"registerWithRegistrar:");
  SEL registrarSelector = NSSelectorFromString(@"registrarForPlugin:");
  if (pluginClass == Nil || ![pluginClass respondsToSelector:registerSelector] ||
      ![engine respondsToSelector:registrarSelector]) {
    NSLog(@"APPBOX_FLUTTER_RUNTIME plugin_missing framework=%@ class=%@",
          framework, className);
    return;
  }
  id registrar = ((id (*)(id, SEL, id))objc_msgSend)(
      engine, registrarSelector, pluginKey);
  ((void (*)(id, SEL, id))objc_msgSend)(
      pluginClass, registerSelector, registrar);
  NSLog(@"APPBOX_FLUTTER_RUNTIME plugin_registered key=%@ class=%@",
        pluginKey, NSStringFromClass(pluginClass));
}

@interface NSBundle (AppBoxPrivate)
- (id)_cfBundle;
@end

@interface NSProcessInfo (AppBoxPrivate)
- (void)setArguments:(NSArray<NSString *> *)arguments;
@end

static void AppBoxScheduleGuestScreenshot(NSTimeInterval delay,
                                          NSString *fileName);

static uint64_t AppBoxAArch64TBNZTarget(uint32_t instruction, uint64_t pc) {
  if ((instruction & 0xFF000000) != 0x37000000) {
    return 0;
  }
  return (((instruction >> 5) & 0xFFFF) * 4) + pc;
}

static uint64_t AppBoxAArch64ADRP(uint32_t instruction, uint64_t pc) {
  if ((instruction & 0x9F000000) != 0x90000000) {
    return 0;
  }

  int32_t immediate = (instruction & 0xFFFFE0) >> 3;
  immediate |= (instruction & 0x60000000) >> 29;
  if (instruction & 0x800000) {
    immediate |= 0xFFE00000;
  }
  return (pc & ~(0xFFFULL)) + ((int64_t)immediate << 12);
}

static uint64_t AppBoxAArch64ADRPAdd(uint32_t adrpInstruction,
                                     uint32_t addInstruction,
                                     uint64_t pc) {
  uint64_t page = AppBoxAArch64ADRP(adrpInstruction, pc);
  if (page == 0 || (addInstruction & 0xFF000000) != 0x91000000) {
    return 0;
  }

  uint32_t source = (addInstruction >> 5) & 0x1F;
  if ((adrpInstruction & 0x1F) != source) {
    return 0;
  }

  uint32_t immediate = (addInstruction & 0x3FFC00) >> 10;
  uint8_t shift = (addInstruction & 0xC00000) >> 22;
  if (shift == 1) {
    immediate <<= 12;
  } else if (shift != 0) {
    return 0;
  }
  return page + immediate;
}

static uint64_t AppBoxAArch64ADRPLoad(uint32_t adrpInstruction,
                                      uint32_t loadInstruction,
                                      uint64_t pc) {
  uint64_t page = AppBoxAArch64ADRP(adrpInstruction, pc);
  if (page == 0 ||
      (adrpInstruction & 0x1F) != ((loadInstruction >> 5) & 0x1F) ||
      (loadInstruction & 0xFFC00000) != 0xF9400000) {
    return 0;
  }
  return page + (((loadInstruction >> 10) & 0xFFF) << 3);
}

static BOOL AppBoxOverwriteMainNSBundle(NSBundle *newBundle) {
#if defined(__arm64__)
  NSBundle *oldBundle = NSBundle.mainBundle;
  uint32_t *implementation = (uint32_t *)method_getImplementation(
      class_getClassMethod(NSBundle.class, @selector(mainBundle)));
  BOOL replaced = NO;

  for (int instructionIndex = 0; instructionIndex < 20; instructionIndex++) {
    void **mergedGlobals = (void **)AppBoxAArch64ADRPAdd(
        implementation[instructionIndex], implementation[instructionIndex + 1],
        (uint64_t)&implementation[instructionIndex]);
    if (mergedGlobals == NULL) {
      continue;
    }

    // iOS 17 and newer can address _MergedGlobals+4 with LDUR.
    if ((implementation[instructionIndex + 4] & 0xFF000000) == 0xF8000000) {
      mergedGlobals = (void **)((uint64_t)mergedGlobals - 4);
    }

    for (int globalIndex = 0; globalIndex < 20; globalIndex++) {
      if (mergedGlobals[globalIndex] == (__bridge void *)oldBundle) {
        mergedGlobals[globalIndex] = (__bridge void *)newBundle;
        replaced = YES;
        break;
      }
    }
  }
  return replaced && NSBundle.mainBundle == newBundle;
#else
  return NO;
#endif
}

static BOOL AppBoxOverwriteMainCFBundle(void) {
#if defined(__arm64__)
  uint32_t *instruction = (uint32_t *)CFBundleGetMainBundle;
  void **mainBundleAddress = NULL;

  if (@available(iOS 27.0, *)) {
    for (int index = 0; index < 100; index++, instruction++) {
      if ((*instruction & 0x7F000000) == 0x36000000) {
        mainBundleAddress = (void **)AppBoxAArch64ADRPLoad(
            *(instruction - 1), *(instruction + 1),
            (uint64_t)(instruction - 1));
        break;
      }
    }
  } else {
    for (int index = 0; index < 100; index++, instruction++) {
      uint64_t jumpAddress =
          AppBoxAArch64TBNZTarget(*instruction, (uint64_t)instruction);
      if (jumpAddress != 0) {
        mainBundleAddress = (void **)AppBoxAArch64ADRPLoad(
            *(instruction - 1), *(uint32_t *)jumpAddress,
            (uint64_t)(instruction - 1));
        break;
      }
    }
  }

  if (mainBundleAddress == NULL || NSBundle.mainBundle._cfBundle == nil) {
    return NO;
  }
  *mainBundleAddress = (__bridge void *)NSBundle.mainBundle._cfBundle;
  return CFBundleGetMainBundle() == (__bridge CFBundleRef)NSBundle.mainBundle._cfBundle;
#else
  return NO;
#endif
}

static BOOL AppBoxInstallGuestProcessIdentity(NSString *bundlePath,
                                               NSString *executablePath) {
  NSBundle *guestBundle = [[NSBundle alloc] initWithPath:bundlePath];
  if (guestBundle == nil) {
    return NO;
  }

  AppBoxGuestMainBundle = guestBundle;
  BOOL nsBundleReplaced = AppBoxOverwriteMainNSBundle(guestBundle);
  BOOL cfBundleReplaced = nsBundleReplaced && AppBoxOverwriteMainCFBundle();

  NSMutableArray<NSString *> *arguments =
      NSProcessInfo.processInfo.arguments.mutableCopy;
  if (arguments.count > 0) {
    arguments[0] = executablePath;
    [NSProcessInfo.processInfo performSelector:@selector(setArguments:)
                                    withObject:arguments];
    Class swiftProcessInfo = NSClassFromString(@"_NSSwiftProcessInfo");
    if (swiftProcessInfo != Nil) {
      SEL argumentsSelector = @selector(arguments);
      method_setImplementation(
          class_getInstanceMethod(swiftProcessInfo, argumentsSelector),
          class_getMethodImplementation(NSProcessInfo.class,
                                        argumentsSelector));
    }
  }
  NSString *processName = guestBundle.infoDictionary[@"CFBundleExecutable"];
  if (processName.length > 0) {
    NSProcessInfo.processInfo.processName = processName;
    setprogname(processName.UTF8String);
  }

  NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_identity nsbundle=%d cfbundle=%d path=%@ identifier=%@ executable=%@",
        nsBundleReplaced, cfBundleReplaced, NSBundle.mainBundle.bundlePath,
        NSBundle.mainBundle.bundleIdentifier,
        NSProcessInfo.processInfo.arguments.firstObject);
  return nsBundleReplaced && cfBundleReplaced;
}

@interface AppBoxFlutterGuestDelegate : UIResponder <UIApplicationDelegate>
@property(nonatomic, strong) UIWindow *window;
@property(nonatomic, strong) id guestEngine;
@end

@implementation AppBoxFlutterGuestDelegate
- (BOOL)application:(UIApplication *)application
    didFinishLaunchingWithOptions:(NSDictionary *)launchOptions {
  NSURL *documentsURL = [NSFileManager.defaultManager
      URLsForDirectory:NSDocumentDirectory
      inDomains:NSUserDomainMask].lastObject;
  NSString *guestBundlePath = [[documentsURL URLByAppendingPathComponent:
      @"Applications/app.nqyqstm6mu.tianya.runtime/Guest.bundle"] path];
  NSBundle *guestBundle = [[NSBundle alloc] initWithPath:guestBundlePath];
  if (guestBundle == nil ||
      ![NSFileManager.defaultManager fileExistsAtPath:
          [guestBundlePath stringByAppendingPathComponent:@"flutter_assets/kernel_blob.bin"]]) {
    NSLog(@"APPBOX_FLUTTER_RUNTIME guest_boot_failed reason=artifact_missing path=%@",
          guestBundlePath);
    return NO;
  }

  Class projectClass = NSClassFromString(@"FlutterDartProject");
  Class engineClass = NSClassFromString(@"FlutterEngine");
  Class controllerClass = NSClassFromString(@"FlutterViewController");
  if (projectClass == Nil || engineClass == Nil || controllerClass == Nil) {
    NSLog(@"APPBOX_FLUTTER_RUNTIME guest_boot_failed reason=flutter_classes_missing");
    return NO;
  }

  id project = ((id (*)(id, SEL, id))objc_msgSend)(
      [projectClass alloc], NSSelectorFromString(@"initWithPrecompiledDartBundle:"),
      guestBundle);
  id engine = ((id (*)(id, SEL, id, id, BOOL))objc_msgSend)(
      [engineClass alloc],
      NSSelectorFromString(@"initWithName:project:allowHeadlessExecution:"),
      @"appbox.pornhub", project, YES);
  BOOL started = ((BOOL (*)(id, SEL, id))objc_msgSend)(
      engine, NSSelectorFromString(@"runWithEntrypoint:"), nil);
  if (!started) {
    NSLog(@"APPBOX_FLUTTER_RUNTIME guest_boot_failed reason=engine_start");
    return NO;
  }
  self.guestEngine = engine;

  // These plugins are required by the startup/account path. They are copied
  // from the exact approved IPA and loaded only in the Flutter guest process.
  AppBoxRegisterFlutterPlugin(engine, @"shared_preferences_foundation",
                              @"SharedPreferencesPlugin",
                              @"SharedPreferencesPlugin");
  AppBoxRegisterFlutterPlugin(engine, @"device_info_plus",
                              @"FPPDeviceInfoPlusPlugin",
                              @"FPPDeviceInfoPlusPlugin");
  AppBoxRegisterFlutterPlugin(engine, @"package_info_plus",
                              @"FPPPackageInfoPlusPlugin",
                              @"FPPPackageInfoPlusPlugin");
  AppBoxRegisterFlutterPlugin(engine, @"connectivity_plus",
                              @"ConnectivityPlusPlugin",
                              @"ConnectivityPlusPlugin");
  AppBoxRegisterFlutterPlugin(engine, @"flutter_secure_storage",
                              @"FlutterSecureStoragePlugin",
                              @"FlutterSecureStoragePlugin");
  AppBoxLoadFramework(@"JNKeychain");
  AppBoxRegisterFlutterPlugin(engine, @"mobile_device_identifier",
                              @"SwiftMobileDeviceIdentifierPlugin",
                              @"SwiftMobileDeviceIdentifierPlugin");
  AppBoxRegisterFlutterPlugin(engine, @"path_provider_foundation",
                              @"PathProviderPlugin",
                              @"PathProviderPlugin");

  UIViewController *controller = ((id (*)(id, SEL, id, id, id))objc_msgSend)(
      [controllerClass alloc], NSSelectorFromString(@"initWithEngine:nibName:bundle:"),
      engine, nil, nil);
  if ([controller respondsToSelector:NSSelectorFromString(@"setFlutterViewDidRenderCallback:")]) {
    void (^firstFrame)(void) = ^{
      NSLog(@"APPBOX_FLUTTER_RUNTIME guest_first_frame");
      AppBoxScheduleGuestScreenshot(1, @"flutter-guest-screen.png");
      AppBoxScheduleGuestScreenshot(15, @"flutter-guest-screen-15.png");
      AppBoxScheduleGuestScreenshot(30, @"flutter-guest-screen-30.png");
    };
    ((void (*)(id, SEL, id))objc_msgSend)(
        controller, NSSelectorFromString(@"setFlutterViewDidRenderCallback:"),
        firstFrame);
  }

  self.window = [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
  self.window.rootViewController = controller;
  [self.window makeKeyAndVisible];
  AppBoxInstallGuestFloatingControl(self.window);
  NSLog(@"APPBOX_FLUTTER_RUNTIME guest_engine_started runtime=flutter_debug_arm64_simulator bundle=app.nqyqstm6mu.tianya");
  return YES;
}
@end

static int AppBoxRunFlutterGuest(int argc, char *argv[]) {
  if (AppBoxLoadFramework(@"Flutter") == NULL) {
    return -1;
  }
  NSLog(@"APPBOX_FLUTTER_RUNTIME guest_boot");
  return UIApplicationMain(argc, argv, nil,
                           NSStringFromClass(AppBoxFlutterGuestDelegate.class));
}

// PBPlayerKit's public NUDGuestHooksInit entry point expects this compatibility
// selector to be supplied by the PlayBox host executable. It uses the value as
// the guest's isolated NSUserDefaults domain identifier.
@interface NSUserDefaults (AppBoxPlayBoxCompatibility)
+ (NSUserDefaults *)mainDefaults;
+ (NSString *)runGuestAppBid;
@end

@implementation NSUserDefaults (AppBoxPlayBoxCompatibility)
+ (NSUserDefaults *)mainDefaults {
  return NSUserDefaults.standardUserDefaults;
}

+ (NSString *)runGuestAppBid {
  NSString *bundleIdentifier = [NSUserDefaults.standardUserDefaults
      stringForKey:@"AppBoxPlayBoxGuestBundleIdentifier"];
  return bundleIdentifier.length > 0
      ? bundleIdentifier
      : @"com.amk2ns2n9j.alan2is71";
}
@end

@interface UNUserNotificationCenter (AppBoxPlayBoxCompatibility)
+ (UNUserNotificationCenter *)mainCenter;
@end

@implementation UNUserNotificationCenter (AppBoxPlayBoxCompatibility)
+ (UNUserNotificationCenter *)mainCenter {
  return UNUserNotificationCenter.currentNotificationCenter;
}
@end

static char AppBoxGuestCrashBuffer[2048];
static volatile sig_atomic_t AppBoxGuestCrashBufferLength = 0;

static void AppBoxGuestCrashHandler(const char *message) {
  static volatile sig_atomic_t handlingGuestCrash = 0;
  if (handlingGuestCrash != 0) {
    const sig_atomic_t bufferedLength = AppBoxGuestCrashBufferLength;
    if (bufferedLength > 0) {
      write(STDERR_FILENO, AppBoxGuestCrashBuffer, (size_t)bufferedLength);
      if (AppBoxDiagnosticSignalFile >= 0) {
        write(AppBoxDiagnosticSignalFile, AppBoxGuestCrashBuffer,
              (size_t)bufferedLength);
      }
    }
    _exit(190);
  }
  handlingGuestCrash = 1;

  const char *safe_message =
      message == NULL ? "unknown guest runtime failure" : message;
  char *buffer = AppBoxGuestCrashBuffer;
  AppBoxGuestCrashBufferLength = 0;
  const char prefix[] = "APPBOX_GUEST_CRASH_RAW error=";
  size_t cursor = 0;
  for (size_t index = 0;
       index < sizeof(prefix) - 1 &&
       cursor < sizeof(AppBoxGuestCrashBuffer) - 1;
       index += 1) {
    buffer[cursor++] = prefix[index];
    AppBoxGuestCrashBufferLength = (sig_atomic_t)cursor;
  }
  for (size_t index = 0;
       safe_message[index] != '\0' &&
       cursor < sizeof(AppBoxGuestCrashBuffer) - 2;
       index += 1) {
    buffer[cursor++] = safe_message[index];
    AppBoxGuestCrashBufferLength = (sig_atomic_t)cursor;
  }
  buffer[cursor++] = '\n';
  AppBoxGuestCrashBufferLength = (sig_atomic_t)cursor;
  write(STDERR_FILENO, buffer, cursor);
  if (AppBoxDiagnosticSignalFile >= 0) {
    write(AppBoxDiagnosticSignalFile, buffer, cursor);
  }
  NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_crash error=%s", safe_message);
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-signals"]) {
    _exit(190);
  }
  if (AppBoxAdversarysAbort != NULL) {
    AppBoxAdversarysAbort(-1);
  }
  handlingGuestCrash = 0;
}

static void AppBoxScheduleGuestScreenshot(NSTimeInterval delay,
                                          NSString *fileName) {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               (int64_t)(delay * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    UIWindow *targetWindow =
        AppBoxCurrentForegroundWindow(UIApplication.sharedApplication);
    if (targetWindow == nil) {
    NSLog(@"APPBOX_RUNTIME guest_screenshot_failed reason=no_window");
      return;
    }

    UIGraphicsBeginImageContextWithOptions(targetWindow.bounds.size, NO,
                                           UIScreen.mainScreen.scale);
    BOOL rendered = [targetWindow drawViewHierarchyInRect:targetWindow.bounds
                                       afterScreenUpdates:YES];
    UIImage *image = UIGraphicsGetImageFromCurrentImageContext();
    UIGraphicsEndImageContext();
    NSData *png = image == nil ? nil : UIImagePNGRepresentation(image);
    NSURL *documentsURL = [NSFileManager.defaultManager
        URLsForDirectory:NSDocumentDirectory
        inDomains:NSUserDomainMask].lastObject;
    NSURL *diagnosticsDirectory = [documentsURL
        URLByAppendingPathComponent:@"AppBoxTest" isDirectory:YES];
    [NSFileManager.defaultManager createDirectoryAtURL:diagnosticsDirectory
                            withIntermediateDirectories:YES
                                             attributes:nil
                                                  error:nil];
    NSURL *screenshotURL = [diagnosticsDirectory
        URLByAppendingPathComponent:fileName];
    BOOL written = [png writeToURL:screenshotURL atomically:YES];
    NSLog(@"APPBOX_RUNTIME guest_screenshot file=%@ rendered=%d written=%d bytes=%lu root=%@",
          fileName, rendered, written, (unsigned long)png.length,
          NSStringFromClass(targetWindow.rootViewController.class));
  });
}

static NSString *AppBoxImageForImplementation(IMP implementation) {
  if (implementation == NULL) {
    return @"missing";
  }
  Dl_info info = {0};
  if (dladdr((const void *)implementation, &info) == 0 ||
      info.dli_fname == NULL) {
    return @"unknown";
  }
  return [NSString stringWithUTF8String:info.dli_fname].lastPathComponent;
}

static void AppBoxInspectGuestRegistration(NSTimeInterval delay) {
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               (int64_t)(delay * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    UIApplication *application = UIApplication.sharedApplication;
    id delegate = application.delegate;
    UIWindow *window = nil;
    if ([delegate respondsToSelector:@selector(window)]) {
      window = ((id (*)(id, SEL))objc_msgSend)(delegate, @selector(window));
    }
    if (window == nil) {
      window = application.windows.firstObject;
    }
    UIViewController *root = window.rootViewController;
    Class registrant = NSClassFromString(@"GeneratedPluginRegistrant");
    Class superPlayer = NSClassFromString(@"SuperPlayerPlugin");
    SEL registerSelector = NSSelectorFromString(@"registerWithRegistry:");
    SEL pluginSelector = NSSelectorFromString(@"registerWithRegistrar:");
    IMP registrantIMP = registrant == Nil ? NULL :
        method_getImplementation(class_getClassMethod(registrant,
                                                       registerSelector));
    IMP superPlayerIMP = superPlayer == Nil ? NULL :
        method_getImplementation(class_getClassMethod(superPlayer,
                                                       pluginSelector));
    SEL hasPluginSelector = NSSelectorFromString(@"hasPlugin:");
    BOOL supportsHasPlugin = [delegate respondsToSelector:hasPluginSelector];
    BOOL hasSuperPlayer = supportsHasPlugin &&
        ((BOOL (*)(id, SEL, id))objc_msgSend)(delegate, hasPluginSelector,
                                             @"SuperPlayerPlugin");
    BOOL hasNoScreenshot = supportsHasPlugin &&
        ((BOOL (*)(id, SEL, id))objc_msgSend)(delegate, hasPluginSelector,
                                             @"NoScreenshotPlugin");
    SEL engineSelector = NSSelectorFromString(@"engine");
    if (![root respondsToSelector:engineSelector]) {
      engineSelector = NSSelectorFromString(@"flutterEngine");
    }
    id engine = [root respondsToSelector:engineSelector]
        ? ((id (*)(id, SEL))objc_msgSend)(root, engineSelector)
        : nil;
    SEL isolateSelector = NSSelectorFromString(@"isolateId");
    id isolateID = [engine respondsToSelector:isolateSelector]
        ? ((id (*)(id, SEL))objc_msgSend)(engine, isolateSelector)
        : nil;
    SEL displayingSelector = NSSelectorFromString(@"isDisplayingFlutterUI");
    BOOL displayingFlutterUI = [root respondsToSelector:displayingSelector] &&
        ((BOOL (*)(id, SEL))objc_msgSend)(root, displayingSelector);
    SEL renderCallbackSelector =
        NSSelectorFromString(@"setFlutterViewDidRenderCallback:");
    if (!AppBoxDiagnosticFirstFrameHooked &&
        [root respondsToSelector:renderCallbackSelector]) {
      AppBoxDiagnosticFirstFrameHooked = YES;
      void (^callback)(void) = ^{
        NSLog(@"APPBOX_DIAGNOSTIC_GUEST_FIRST_FRAME");
      };
      ((void (*)(id, SEL, id))objc_msgSend)(root, renderCallbackSelector,
                                           callback);
    }
    NSLog(@"APPBOX_DIAGNOSTIC_GUEST_STATE delay=%.0f delegate=%@ root=%@ "
          "registrant=%@ registrant_image=%@ super_player=%@ "
          "super_player_image=%@ has_api=%d has_super_player=%d "
          "has_no_screenshot=%d engine=%@ isolate=%@ displaying=%d "
          "view_window=%d subviews=%lu layer=%@",
          delay, NSStringFromClass([delegate class]),
          NSStringFromClass([root class]), NSStringFromClass(registrant),
          AppBoxImageForImplementation(registrantIMP),
          NSStringFromClass(superPlayer),
          AppBoxImageForImplementation(superPlayerIMP), supportsHasPlugin,
          hasSuperPlayer, hasNoScreenshot, NSStringFromClass([engine class]),
          isolateID, displayingFlutterUI, root.view.window != nil,
          (unsigned long)root.view.subviews.count,
          NSStringFromClass([root.view.layer class]));
  });
}

static int AppBoxRunPlayBoxGuest(int argc, char *argv[]) {
  NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
  NSString *bundleIdentifier = [defaults
      stringForKey:@"AppBoxPlayBoxGuestBundleIdentifier"];
  if (bundleIdentifier.length == 0) {
    bundleIdentifier = @"com.amk2ns2n9j.alan2is71";
  }
  NSString *storageIdentifier = [defaults
      stringForKey:@"AppBoxPlayBoxGuestStorageIdentifier"];
  if (storageIdentifier.length == 0) {
    storageIdentifier = bundleIdentifier;
  }

  // The app data container UUID changes when a development build is replaced.
  // Rebuild paths from the current sandbox instead of trusting persisted
  // absolute paths from the previous installation.
  NSURL *documentsURL = [NSFileManager.defaultManager
      URLsForDirectory:NSDocumentDirectory
      inDomains:NSUserDomainMask].lastObject;
  NSString *bundlePath = [[documentsURL URLByAppendingPathComponent:
      [NSString stringWithFormat:@"Applications/%@.app", storageIdentifier]] path];
  NSDictionary *guestInfo = [NSDictionary dictionaryWithContentsOfFile:
      [bundlePath stringByAppendingPathComponent:@"Info.plist"]];
  NSString *executableName = guestInfo[@"CFBundleExecutable"];
  NSString *executablePath = executableName.length > 0
      ? [bundlePath stringByAppendingPathComponent:executableName]
      : @"";
  NSString *nivmPath = [bundlePath stringByAppendingPathComponent:@"rocketship.nivm"];

  [defaults setObject:bundlePath forKey:AppBoxGuestBundleKey];
  [defaults setObject:executablePath forKey:AppBoxGuestExecutableKey];
  [defaults setObject:nivmPath forKey:AppBoxGuestNIVMKey];

  if (bundlePath.length == 0 || executablePath.length == 0 || nivmPath.length == 0) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_boot_failed reason=missing_paths");
    [defaults setBool:NO forKey:AppBoxGuestModeKey];
    return -1;
  }

  NSFileManager *files = NSFileManager.defaultManager;
  if (![files fileExistsAtPath:bundlePath] ||
      ![files fileExistsAtPath:executablePath] ||
      ![files fileExistsAtPath:nivmPath]) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_boot_failed reason=artifact_missing");
    [defaults setBool:NO forKey:AppBoxGuestModeKey];
    return -1;
  }

  if (!AppBoxLoadPlayBoxRuntime()) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_boot_failed reason=runtime_load");
    return -1;
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-preload-native-app"]) {
    void *nativeApp = AppBoxLoadFramework(@"App");
    NSLog(@"APPBOX_PLAYBOX_RUNTIME native_app_preload=%d", nativeApp != NULL);
    if (nativeApp == NULL) {
      return -1;
    }
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-preload-native-flutter"]) {
    void *nativeFlutter = AppBoxLoadFramework(@"Flutter");
    Class nativeChannelClass = NSClassFromString(@"FlutterMethodChannel");
    NSLog(@"APPBOX_PLAYBOX_RUNTIME native_flutter_preload=%d channel=%p image=%s",
          nativeFlutter != NULL, nativeChannelClass,
          nativeChannelClass == Nil
              ? "missing"
              : (class_getImageName(nativeChannelClass) ?: "unknown"));
    if (nativeFlutter == NULL || nativeChannelClass == Nil) {
      return -1;
    }
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-observe-connect"]) {
    AppBoxInstallConnectObservation();
  }
  // DYZB's translated plugin class cannot safely service the YunCeng method
  // channel after PBPlayerKit has installed its Flutter runtime.  The direct
  // device harness used to opt into the host bridge explicitly, but a normal
  // launcher self-restart has no diagnostic arguments.  Select the same
  // verified bridge from the persisted guest identity so the user-facing
  // Start button and the harness execute an identical runtime path.
  BOOL nativeYunCengPlugin =
      [NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-native-yunceng-plugin"] ||
      [bundleIdentifier isEqualToString:@"ady.DYZB168dyzb.app"];
  if (nativeYunCengPlugin) {
    AppBoxInstallNativeYunCengPluginClass();
  }
  NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_boot bundle=%@", bundlePath.lastPathComponent);
  if (!AppBoxInstallGuestProcessIdentity(bundlePath, executablePath)) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_boot_failed reason=identity_redirect");
    [defaults setBool:NO forKey:AppBoxGuestModeKey];
    return -1;
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-bridge-kiwi-listener"]) {
    AppBoxInstallKiwiListenerBridge();
  }
  AppBoxNUDGuestHooksInit();
  AppBoxAdversarysHandler(AppBoxGuestCrashHandler);
  // adversarys_4 accepts an Objective-C class name (it resolves the class and
  // metaclass with objc_getClass/object_getClass), not a framework name.
  // PBPlayerKit already loads KiwiWrap and therefore owns the process-wide
  // `Kiwi` class; register that class so guest references are bound to the
  // compatible host implementation instead of a duplicate translated class.
  if (![NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-use-translated-kiwi"]) {
    AppBoxAdversarysClass("Kiwi");
  }
  if (nativeYunCengPlugin) {
    AppBoxAdversarysClass("FlutterYunCengKiwiPlugin");
  }
  AppBoxAdversarysClass("MJFoundation");
  AppBoxAdversarysClass("MJProperty");
  AppBoxAdversarysClass("MJPropertyKey");
  AppBoxAdversarysClass("MJPropertyType");

  BOOL looseRuntime =
      [NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-run-dyzb-gq-loose"] ||
      [NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-run-chungong-loose"];
  NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_open mode=%@",
        looseRuntime ? @"loose" : @"nivm");
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-signals"]) {
    AppBoxInstallDiagnosticSignalHandler();
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-bridge-guest-callbacks"] ||
      [NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-bridge-dispatch-once-import"]) {
    AppBoxInstallGuestCallbackBridges();
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-terminate"]) {
    AppBoxInstallDiagnosticTerminateHandler();
  }
  if (looseRuntime && !AppBoxPreloadLooseGuestImages(bundlePath)) {
    [defaults setBool:NO forKey:AppBoxGuestModeKey];
    return -1;
  }
  // Test-only LLDB synchronization point.  Starting the process suspended at
  // dyld changes the earliest framework-loading timing on a physical device.
  // Stop here instead, after PBPlayerKit/adversarys and libc++abi are loaded,
  // so exception breakpoints can be resolved before the guest parser runs.
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-debug-stop-before-guest"]) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME debug_stop_before_guest");
    raise(SIGSTOP);
    NSLog(@"APPBOX_PLAYBOX_RUNTIME debug_resumed_before_guest");
  }
  AppBoxStartDiagnosticFileBurst(@"guest_open");
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-focused-result"]) {
    AppBoxStartDiagnosticFocusedBurst();
  }
  AppBoxLogDiagnosticMemory(@"before_guest_open");
  void *guest = looseRuntime
      ? AppBoxAdversarysOpenLoose(executablePath.fileSystemRepresentation)
      : AppBoxAdversarysOpen(executablePath.fileSystemRepresentation,
                            nivmPath.fileSystemRepresentation);
  if (guest == NULL) {
    const char *error = AppBoxAdversarysError();
    NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_open_failed error=%s",
          error == NULL ? "unknown" : error);
    [defaults setBool:NO forKey:AppBoxGuestModeKey];
    return -1;
  }
  // Test-only LLDB synchronization point after adversarys has parsed every
  // Mach-O and resolved its native imports.  This avoids putting a global
  // dlopen/dlsym breakpoint on the expensive guest_open phase when diagnosing
  // Flutter's later App.framework snapshot lookup.
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-debug-stop-after-guest-open"]) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME debug_stop_after_guest_open");
    raise(SIGSTOP);
    NSLog(@"APPBOX_PLAYBOX_RUNTIME debug_resumed_after_guest_open");
  }
  if ([bundleIdentifier isEqualToString:@"com.cg.client.pro"] &&
      !AppBoxInstallChungongKingfisherWrapperMetadataCompatibility()) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_boot_failed "
          "reason=kingfisher_wrapper_metadata");
    return -1;
  }
  if ([bundleIdentifier isEqualToString:@"com.cg.client.pro"] &&
      !AppBoxInstallChungongKingfisherImageResourceMetadataCompatibility()) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_boot_failed "
          "reason=kingfisher_image_resource_metadata");
    return -1;
  }
  if ([bundleIdentifier isEqualToString:@"com.cg.client.pro"] &&
      !AppBoxInstallChungongKingfisherDownloadTaskMetadataCompatibility()) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_boot_failed "
          "reason=kingfisher_download_task_metadata");
    return -1;
  }
  if ([bundleIdentifier isEqualToString:@"com.cg.client.pro"] &&
      !AppBoxRegisterMappedGuestSwiftMetadata()) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_boot_failed "
          "reason=swift_metadata_registration");
    return -1;
  }
  if ([bundleIdentifier isEqualToString:@"com.cg.client.pro"]) {
    AppBoxInstallChungongUIKitCompatibility();
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-bridge-dyzb-kiwi-plugin"]) {
    AppBoxInstallDyzbKiwiPluginBridge();
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-prepare-dyzb-kiwi"]) {
    AppBoxInstallDyzbKiwiPrepareBridge();
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-bridge-dyzb-kiwi-class"]) {
    AppBoxInstallDyzbKiwiClassBridge();
  }

  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-signals"]) {
    static const char *const snapshotSymbols[] = {
      "kDartVmSnapshotData",
      "kDartVmSnapshotInstructions",
      "kDartIsolateSnapshotData",
      "kDartIsolateSnapshotInstructions",
    };
    for (NSUInteger index = 0;
         index < sizeof(snapshotSymbols) / sizeof(snapshotSymbols[0]);
         index += 1) {
      const char *symbol = snapshotSymbols[index];
      void *guestSymbol = AppBoxAdversarysSymbol(guest, symbol);
      void *processSymbol = dlsym(RTLD_DEFAULT, symbol);
      NSLog(@"APPBOX_DIAGNOSTIC_SNAPSHOT symbol=%s guest=%p process=%p",
            symbol, guestSymbol, processSymbol);
    }
    NSString *appFrameworkPath = [bundlePath
        stringByAppendingPathComponent:@"Frameworks/App.framework/App"];
    NSLog(@"APPBOX_DIAGNOSTIC_SNAPSHOT app_path=%@ exists=%d bundle_resource=%@",
          appFrameworkPath,
          [NSFileManager.defaultManager fileExistsAtPath:appFrameworkPath],
          [NSBundle.mainBundle pathForResource:@"Frameworks/App.framework"
                                       ofType:@""]);
  }

  typedef int (*GuestMain)(int, char **);
  GuestMain guestMain = (GuestMain)AppBoxAdversarysSymbol(guest, "main");
  if (guestMain == NULL) {
    const char *error = AppBoxAdversarysError();
    NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_main_missing error=%s",
          error == NULL ? "unknown" : error);
    [defaults setBool:NO forKey:AppBoxGuestModeKey];
    return -1;
  }

  if (AppBoxInProcessGuestBootstrap) {
    UIApplication *application = UIApplication.sharedApplication;
    BOOL guestBuildsOwnWindow =
        [bundleIdentifier isEqualToString:@"com.cg.client.pro"];
    BOOL preserveHostApplicationDelegate = guestBuildsOwnWindow ||
        [bundleIdentifier isEqualToString:@"com.laodeng.worldcupapp"];
    NSString *swiftModule = guestInfo[@"CFBundleExecutable"];
    NSMutableArray<NSString *> *delegateClassNames =
        [NSMutableArray array];
    if (swiftModule.length > 0) {
      [delegateClassNames addObject:
          [NSString stringWithFormat:@"%@.AppDelegate", swiftModule]];
      NSUInteger moduleByteLength =
          [swiftModule lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
      [delegateClassNames addObject:
          [NSString stringWithFormat:@"_TtC%lu%@11AppDelegate",
                                     (unsigned long)moduleByteLength,
                                     swiftModule]];
    }
    [delegateClassNames addObject:@"AppDelegate"];
    Class delegateClass = Nil;
    NSString *delegateClassName = nil;
    for (NSString *candidateName in delegateClassNames) {
      delegateClass = NSClassFromString(candidateName);
      if (delegateClass == Nil) {
        delegateClass = objc_getClass(candidateName.UTF8String);
      }
      if (delegateClass != Nil) {
        delegateClassName = candidateName;
        break;
      }
    }
    if (delegateClass == Nil) {
      NSLog(@"APPBOX_PLAYBOX_RUNTIME in_process_failed "
            "reason=delegate_missing candidates=%@",
            delegateClassNames);
      return -1;
    }
    NSLog(@"APPBOX_PLAYBOX_RUNTIME in_process_delegate class=%@ candidate=%@",
          NSStringFromClass(delegateClass), delegateClassName);
    id hostDelegate = application.delegate;
    UIWindow *hostWindow = nil;
    if ([hostDelegate respondsToSelector:@selector(window)]) {
      hostWindow = ((id (*)(id, SEL))objc_msgSend)(hostDelegate,
                                                   @selector(window));
    }
    if (hostWindow == nil) {
      hostWindow = AppBoxCurrentForegroundWindow(application);
    }
    NSLog(@"APPBOX_PLAYBOX_RUNTIME host_window_captured delegate=%@ window=%@ "
          "key=%d hidden=%d",
          NSStringFromClass([hostDelegate class]),
          NSStringFromClass(hostWindow.class), hostWindow.isKeyWindow,
          hostWindow.hidden);
    NSLog(@"APPBOX_PLAYBOX_RUNTIME delegate_alloc_begin class=%@",
          NSStringFromClass(delegateClass));
    id guestDelegate = [delegateClass alloc];
    NSLog(@"APPBOX_PLAYBOX_RUNTIME delegate_alloc_end object=%p class=%@",
          (__bridge void *)guestDelegate,
          guestDelegate == nil ? @"nil" : NSStringFromClass([guestDelegate class]));
    NSLog(@"APPBOX_PLAYBOX_RUNTIME delegate_init_begin object=%p",
          (__bridge void *)guestDelegate);
    guestDelegate = [guestDelegate init];
    NSLog(@"APPBOX_PLAYBOX_RUNTIME delegate_init_end object=%p class=%@",
          (__bridge void *)guestDelegate,
          guestDelegate == nil ? @"nil" : NSStringFromClass([guestDelegate class]));
    SEL setDelegateSelector = NSSelectorFromString(@"setDelegate:");
    if (guestDelegate == nil ||
        ![application respondsToSelector:setDelegateSelector]) {
      NSLog(@"APPBOX_PLAYBOX_RUNTIME in_process_failed reason=delegate_setter");
      return -1;
    }
    AppBoxInProcessGuestDelegate = guestDelegate;
    if (preserveHostApplicationDelegate) {
      // Keep the launcher as UIApplication's system delegate. UIKit/FrontBoard
      // associates the active scene and its key window with that delegate;
      // replacing it after launch makes the process terminate. The guest
      // lifecycle is driven explicitly below and the guest delegate is retained
      // independently in AppBoxInProcessGuestDelegate.
      NSLog(@"APPBOX_PLAYBOX_RUNTIME application_delegate_preserved class=%@",
            NSStringFromClass([hostDelegate class]));
    } else {
      NSLog(@"APPBOX_PLAYBOX_RUNTIME application_delegate_set_begin class=%@",
            NSStringFromClass([guestDelegate class]));
      ((void (*)(id, SEL, id))objc_msgSend)(application, setDelegateSelector,
                                            guestDelegate);
      NSLog(@"APPBOX_PLAYBOX_RUNTIME application_delegate_set_end class=%@",
            NSStringFromClass([application.delegate class]));
    }

    // UIApplicationMain normally creates UIMainStoryboardFile and assigns its
    // window before calling the app delegate. Because the AppBox launcher has
    // already completed that work for its own delegate, reproduce the same
    // ordering for the selected guest.
    UIViewController *guestRoot = nil;
    UIWindow *guestWindow = nil;
    if (!guestBuildsOwnWindow) {
      NSString *storyboardName = guestInfo[@"UIMainStoryboardFile"];
      if (storyboardName.length == 0) {
        storyboardName = guestInfo[@"NSMainStoryboardFile"];
      }
      if (storyboardName.length == 0 &&
          [AppBoxGuestMainBundle pathForResource:@"Main"
                                          ofType:@"storyboardc"] != nil) {
        storyboardName = @"Main";
      }
      if (storyboardName.length > 0) {
        NSLog(@"APPBOX_PLAYBOX_RUNTIME storyboard_create_begin name=%@ "
              "bundle=%@ path=%@",
              storyboardName, AppBoxGuestMainBundle.bundleIdentifier,
              AppBoxGuestMainBundle.bundlePath);
        UIStoryboard *storyboard =
            [UIStoryboard storyboardWithName:storyboardName
                                      bundle:AppBoxGuestMainBundle];
        NSLog(@"APPBOX_PLAYBOX_RUNTIME storyboard_create_end storyboard=%p",
              (__bridge void *)storyboard);
        NSLog(@"APPBOX_PLAYBOX_RUNTIME storyboard_instantiate_begin");
        guestRoot = [storyboard instantiateInitialViewController];
        NSLog(@"APPBOX_PLAYBOX_RUNTIME storyboard_instantiate_end root=%p class=%@",
              (__bridge void *)guestRoot,
              guestRoot == nil ? @"nil" : NSStringFromClass([guestRoot class]));
      } else {
        // Several PlayBox-converted UIKit/HBuilder guests intentionally have
        // no UIMainStoryboardFile. UIApplicationMain still supplies a window;
        // the guest AppDelegate populates it from didFinishLaunching. Mirror
        // that contract with a neutral root instead of assuming Main.storyboard.
        guestRoot = [[UIViewController alloc] init];
        guestRoot.view.backgroundColor = UIColor.blackColor;
        NSLog(@"APPBOX_PLAYBOX_RUNTIME storyboard_absent fallback_root=%@",
              NSStringFromClass(guestRoot.class));
      }
      if (hostWindow.windowScene != nil) {
        NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_window_create_begin mode=scene");
        guestWindow =
            [[UIWindow alloc] initWithWindowScene:hostWindow.windowScene];
      } else {
        NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_window_create_begin mode=frame");
        guestWindow =
            [[UIWindow alloc] initWithFrame:UIScreen.mainScreen.bounds];
      }
      NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_window_create_end window=%p",
            (__bridge void *)guestWindow);
      guestWindow.rootViewController = guestRoot;
      NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_window_root_set class=%@",
            NSStringFromClass([guestRoot class]));
      SEL setWindowSelector = @selector(setWindow:);
      if ([guestDelegate respondsToSelector:setWindowSelector]) {
        NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_delegate_window_set_begin");
        ((void (*)(id, SEL, id))objc_msgSend)(guestDelegate,
                                              setWindowSelector, guestWindow);
        NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_delegate_window_set_end");
      }
    } else {
      NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_window_mode=delegate");
      // The Chungong AppDelegate allocates and assigns its UIWindow before
      // makeKeyAndVisible. Pre-instantiating the storyboard here schedules its
      // translated lifecycle methods while didFinish is still running and
      // makes the non-reentrant guest interpreter reuse its return state.
      AppBoxInstallChungongUIKitCompatibility();
      AppBoxPrewarmChungongUIViewControllerMetadata();
      AppBoxPrewarmChungongKingfisherWrapperMetadata();
      AppBoxInstallChungongObjectMapperCompatibility();
      AppBoxInstallChungongObjectMapperMetadataCompatibility();
      AppBoxInstallChungongAppearanceEnumCompatibility();
      AppBoxPrewarmChungongModelWitness();
      AppBoxInstallChungongModelValueWitnessCompatibility();
    }

    NSDictionary *launchOptions = @{};
    SEL willFinish = @selector(application:willFinishLaunchingWithOptions:);
    SEL didFinish = @selector(application:didFinishLaunchingWithOptions:);
    BOOL willResult = YES;
    BOOL didResult = YES;
    BOOL deferredGuestWindowVisibility =
        [bundleIdentifier isEqualToString:@"com.cg.client.pro"]
            ? AppBoxBeginGuestWindowVisibilityDeferral()
            : NO;
    if ([guestDelegate respondsToSelector:willFinish]) {
      NSLog(@"APPBOX_PLAYBOX_RUNTIME will_finish_begin");
      willResult = ((BOOL (*)(id, SEL, id, id))objc_msgSend)(
          guestDelegate, willFinish, application, launchOptions);
      NSLog(@"APPBOX_PLAYBOX_RUNTIME will_finish_end result=%d", willResult);
    }
    if (willResult && [guestDelegate respondsToSelector:didFinish]) {
      NSLog(@"APPBOX_PLAYBOX_RUNTIME did_finish_begin");
      didResult = ((BOOL (*)(id, SEL, id, id))objc_msgSend)(
          guestDelegate, didFinish, application, launchOptions);
      NSLog(@"APPBOX_PLAYBOX_RUNTIME did_finish_end result=%d", didResult);
    }
    AppBoxEndGuestWindowVisibilityDeferral(deferredGuestWindowVisibility,
                                           !guestBuildsOwnWindow);
    SEL windowSelector = @selector(window);
    if ([guestDelegate respondsToSelector:windowSelector]) {
      id delegateWindow = ((id (*)(id, SEL))objc_msgSend)(guestDelegate,
                                                          windowSelector);
      if (delegateWindow != nil) {
        guestWindow = delegateWindow;
      }
    }
    AppBoxInProcessGuestWindow =
        guestBuildsOwnWindow ? hostWindow : guestWindow;
    SEL becameActive = @selector(applicationDidBecomeActive:);
    if (guestBuildsOwnWindow) {
      // UIKit activates the new root controller synchronously from
      // makeKeyAndVisible. Running that lifecycle while the translated guest
      // launch callback is unwinding makes the non-reentrant interpreter race
      // its dispatch/reachability callbacks. Move the entire window handoff to
      // a later main-runloop turn and retain the guest window independently of
      // the translated AppDelegate property.
      NSLog(@"APPBOX_PLAYBOX_RUNTIME window_activation_scheduled window=%@",
            NSStringFromClass(guestWindow.class));
      dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                   (int64_t)(0.20 * NSEC_PER_SEC)),
                     dispatch_get_main_queue(), ^{
        UIWindow *deferredGuestWindow = nil;
        UIViewController *deferredGuestController =
            AppBoxTakeDeferredGuestRootController(&deferredGuestWindow);
        UIViewController *nativeContainer = [[UIViewController alloc] init];
        nativeContainer.view.backgroundColor = UIColor.blackColor;
        UIImage *launchImage = [UIImage imageNamed:@"ic_welcome_m"
                                          inBundle:AppBoxGuestMainBundle
                         compatibleWithTraitCollection:nil];
        UIImageView *launchImageView = [[UIImageView alloc]
            initWithFrame:nativeContainer.view.bounds];
        launchImageView.autoresizingMask =
            UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
        launchImageView.contentMode = UIViewContentModeScaleAspectFill;
        launchImageView.clipsToBounds = YES;
        launchImageView.image = launchImage;
        [nativeContainer.view addSubview:launchImageView];
        UIActivityIndicatorView *launchIndicator = [[UIActivityIndicatorView alloc]
            initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleLarge];
        launchIndicator.translatesAutoresizingMaskIntoConstraints = NO;
        launchIndicator.color = UIColor.whiteColor;
        [launchIndicator startAnimating];
        [nativeContainer.view addSubview:launchIndicator];
        [NSLayoutConstraint activateConstraints:@[
          [launchIndicator.centerXAnchor
              constraintEqualToAnchor:nativeContainer.view.centerXAnchor],
          [launchIndicator.bottomAnchor
              constraintEqualToAnchor:nativeContainer.view.safeAreaLayoutGuide
                                          .bottomAnchor
                         constant:-36.0],
        ]];
        NSLog(@"APPBOX_PLAYBOX_RUNTIME native_container_apply_begin");
        ((void (*)(id, SEL, id))AppBoxOriginalSetRootViewController)(
            hostWindow, @selector(setRootViewController:), nativeContainer);
        hostWindow.hidden = NO;
        AppBoxInstallGuestFloatingControl(hostWindow);
        NSLog(@"APPBOX_PLAYBOX_RUNTIME native_container_applied window=%@",
              NSStringFromClass(hostWindow.class));
        dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                                     (int64_t)(0.10 * NSEC_PER_SEC)),
                       dispatch_get_main_queue(), ^{
          NSLog(@"APPBOX_PLAYBOX_RUNTIME native_launch_surface_ready image=%d "
                "guest_controller=%@",
                launchImage != nil,
                NSStringFromClass(deferredGuestController.class));
          NSLog(@"APPBOX_PLAYBOX_RUNTIME in_process_ready delegate=%@ will=%d "
                "did=%d window=%@ root=%@ guest_root=%@",
                NSStringFromClass(delegateClass), willResult, didResult,
                NSStringFromClass([hostWindow class]),
                NSStringFromClass([[hostWindow rootViewController] class]),
                NSStringFromClass(deferredGuestController.class));
          Class tabControllerClass =
              NSClassFromString(@"Seal.ApplicationTabBarViewController");
          if (tabControllerClass == Nil) {
            tabControllerClass = objc_getClass(
                "_TtC4Seal31ApplicationTabBarViewController");
          }
          NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_bootstrap_begin class=%@",
                NSStringFromClass(tabControllerClass));
          if (tabControllerClass == Nil) {
            NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_bootstrap_failed "
                  "reason=class_missing");
            return;
          }
          SEL tabInitializer = @selector(initWithNibName:bundle:);
          Method nativeTabInitializer = class_getInstanceMethod(
              class_getSuperclass(tabControllerClass), tabInitializer);
          if (nativeTabInitializer == NULL) {
            NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_bootstrap_failed "
                  "reason=super_initializer_missing");
            return;
          }
          NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_alloc_begin");
          id allocatedTabController = [tabControllerClass alloc];
          NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_alloc_end object=%@",
                NSStringFromClass([allocatedTabController class]));
          Class nativeTabControllerClass =
              class_getSuperclass(tabControllerClass);
          Class allocatedTabControllerClass = object_setClass(
              allocatedTabController, nativeTabControllerClass);
          NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_native_isa_applied old=%@ new=%@",
                NSStringFromClass(allocatedTabControllerClass),
                NSStringFromClass([allocatedTabController class]));
          NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_super_init_begin imp=%p",
                method_getImplementation(nativeTabInitializer));
          UIViewController *tabController =
              ((id (*)(id, SEL, id, id))method_getImplementation(
                  nativeTabInitializer))(allocatedTabController,
                                         tabInitializer, nil, nil);
          if (tabController != nil) {
            object_setClass(tabController, tabControllerClass);
          }
          NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_super_init_end object=%@",
                NSStringFromClass(tabController.class));
          AppBoxInProcessGuestRootController = tabController;
          NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_bootstrap_end controller=%@ "
                "super=%@ view_loaded=%d",
                NSStringFromClass(tabController.class),
                NSStringFromClass(class_getSuperclass(tabControllerClass)),
                tabController.isViewLoaded);
          Method guestTabViewDidLoad = class_getInstanceMethod(
              tabControllerClass, @selector(viewDidLoad));
          IMP guestTabViewDidLoadImplementation =
              guestTabViewDidLoad == NULL
                  ? NULL
                  : method_getImplementation(guestTabViewDidLoad);
          NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_view_did_load_begin imp=%p",
                guestTabViewDidLoadImplementation);
          if (guestTabViewDidLoadImplementation != NULL) {
            object_setClass(tabController, nativeTabControllerClass);
            ((void (*)(id, SEL))guestTabViewDidLoadImplementation)(
                tabController, @selector(viewDidLoad));
            object_setClass(tabController, tabControllerClass);
          }
          NSLog(@"APPBOX_PLAYBOX_RUNTIME tab_view_did_load_end children=%lu "
                "subviews=%lu",
                (unsigned long)tabController.childViewControllers.count,
                (unsigned long)tabController.view.subviews.count);
        });
      });
    } else {
      [guestWindow makeKeyAndVisible];
      hostWindow.hidden = YES;
      AppBoxInstallGuestFloatingControl(guestWindow);
      if (didResult && [guestDelegate respondsToSelector:becameActive]) {
        ((void (*)(id, SEL, id))objc_msgSend)(guestDelegate, becameActive,
                                              application);
      }
      NSLog(@"APPBOX_PLAYBOX_RUNTIME in_process_ready delegate=%@ will=%d "
            "did=%d window=%@ root=%@",
            NSStringFromClass(delegateClass), willResult, didResult,
            NSStringFromClass([guestWindow class]),
            NSStringFromClass([[guestWindow rootViewController] class]));
    }
    AppBoxScheduleGuestScreenshot(5, @"inprocess-guest-screen-05.png");
    AppBoxScheduleGuestScreenshot(15, @"inprocess-guest-screen-15.png");
    AppBoxScheduleGuestScreenshot(30, @"inprocess-guest-screen-30.png");
    return willResult && didResult && guestWindow != nil ? 0 : -1;
  }

  NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_main_start");
  AppBoxLogDiagnosticMemory(@"before_guest_main");
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-signals"]) {
    AppBoxInstallDiagnosticSignalHandler();
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-samples"]) {
    AppBoxInstallDiagnosticSampler();
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-diagnostic-thread-samples"]) {
    AppBoxScheduleDiagnosticThreadSampler();
    AppBoxInspectGuestRegistration(2);
    AppBoxInspectGuestRegistration(10);
  }
  if ([NSProcessInfo.processInfo.arguments
          containsObject:@"--appbox-debug-stop-before-guest-main"]) {
    NSLog(@"APPBOX_PLAYBOX_RUNTIME debug_wait_before_guest_main");
    sleep(12);
  }
  argv[0] = strdup(executablePath.fileSystemRepresentation);
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW,
                               (int64_t)(2.0 * NSEC_PER_SEC)),
                 dispatch_get_main_queue(), ^{
    AppBoxInstallGuestFloatingControl(
        AppBoxCurrentForegroundWindow(UIApplication.sharedApplication));
  });
  AppBoxScheduleGuestScreenshot(5, @"guest-screen-05.png");
  AppBoxScheduleGuestScreenshot(15, @"guest-screen-15.png");
  AppBoxScheduleGuestScreenshot(30, @"guest-screen-30.png");
  AppBoxScheduleGuestScreenshot(60, @"guest-screen-60.png");
  AppBoxScheduleGuestScreenshot(120, @"guest-screen-120.png");
  AppBoxScheduleGuestScreenshot(180, @"guest-screen-180.png");
  dispatch_after(dispatch_time(DISPATCH_TIME_NOW, 60 * NSEC_PER_SEC),
                 dispatch_get_main_queue(), ^{
    [NSFileManager.defaultManager
        removeItemAtURL:AppBoxPlayBoxContinuationMarkerURL()
                  error:nil];
  });
  int result = guestMain(argc, argv);
  NSLog(@"APPBOX_PLAYBOX_RUNTIME guest_main_returned code=%d", result);
  return result;
}

int AppBoxLaunchSelectedPlayBoxGuestInProcess(void) {
  AppBoxInProcessGuestBootstrap = YES;
  const char *executable = NSBundle.mainBundle.executablePath.fileSystemRepresentation;
  char *arguments[] = {(char *)executable, NULL};
  int result = AppBoxRunPlayBoxGuest(1, arguments);
  AppBoxInProcessGuestBootstrap = NO;
  return result;
}

int main(int argc, char *argv[]) {
  @autoreleasepool {
    AppBoxHostBundle = NSBundle.mainBundle;
    NSArray<NSString *> *processArguments = NSProcessInfo.processInfo.arguments;
    NSUInteger decryptProbeIndex =
        [processArguments indexOfObject:@"--appbox-probe-lnkiwi-decrypt"];
    if (decryptProbeIndex != NSNotFound) {
      if (decryptProbeIndex + 1 >= processArguments.count) {
        NSLog(@"APPBOX_LNKIWI_DECRYPT error=missing_argument");
        return 64;
      }
      if (AppBoxLoadFramework(@"PBPlayerKit") == NULL) {
        NSLog(@"APPBOX_LNKIWI_DECRYPT error=framework_load_failed");
        return 65;
      }
      NSString *encrypted = processArguments[decryptProbeIndex + 1];
      AppBoxProbeLNKiwiDecrypt(encrypted.UTF8String);
      return 0;
    }

    if ([NSProcessInfo.processInfo.arguments
            containsObject:@"--appbox-playbox-developer"]) {
      return UIApplicationMain(
          argc, argv, nil,
          NSStringFromClass(NSClassFromString(@"AppBoxHostDelegate")));
    }

    NSUserDefaults *defaults = NSUserDefaults.standardUserDefaults;
    BOOL installCommand = NO;
    for (NSString *argument in processArguments) {
      if ([argument hasPrefix:@"--appbox-install-"]) {
        installCommand = YES;
        break;
      }
    }
    if (installCommand ||
        [processArguments containsObject:@"--appbox-clear-launch-state"]) {
      [defaults removeObjectForKey:AppBoxRuntimeLaunchTokenKey];
      [defaults removeObjectForKey:AppBoxGuestLaunchTokenKey];
      [defaults removeObjectForKey:AppBoxGuestModeKey];
      [defaults synchronize];
      [NSFileManager.defaultManager
          removeItemAtURL:AppBoxPlayBoxContinuationMarkerURL()
                    error:nil];
      NSLog(@"APPBOX_RUNTIME launch_state_cleared reason=%@",
            installCommand ? @"install" : @"explicit");
    }
    // Deterministic real-device harness: bypass the launcher/relaunch hop so
    // devicectl can keep stdout attached while a selected PlayBox guest boots.
    // These arguments are test-only one-shot commands; normal UI launches keep
    // using AppBoxLauncherViewController's relaunch flow.
    NSDictionary<NSString *, NSDictionary<NSString *, NSString *> *>
        *directPlayBoxGuests = @{
      @"--appbox-run-tianya-348-direct": @{
        @"bundle": @"com.laodeng.worldcupapp",
        @"storage": @"tianya_348",
      },
      @"--appbox-run-adult-douyin-direct": @{
        @"bundle": @"com.amk2ns2n9j.alan2is71",
        @"storage": @"com.amk2ns2n9j.alan2is71",
      },
      @"--appbox-run-dyzb-gq-direct": @{
        @"bundle": @"ady.DYZB168dyzb.app",
        @"storage": @"dyzb_gq",
      },
      @"--appbox-run-dyzb-gq-loose": @{
        @"bundle": @"ady.DYZB168dyzb.app",
        @"storage": @"dyzb_gq",
      },
      @"--appbox-run-dyzb-tf-direct": @{
        @"bundle": @"ady.DYZB168dyzb.app",
        @"storage": @"dyzb_tf",
      },
      @"--appbox-run-chungong-direct": @{
        @"bundle": @"com.cg.client.pro",
        @"storage": @"chungong_3_9_1",
      },
      @"--appbox-run-chungong-loose": @{
        @"bundle": @"com.cg.client.pro",
        @"storage": @"chungong_3_9_1",
      },
      @"--appbox-run-ig-xiongmao-direct": @{
        @"bundle": @"com.igvideo.jingdong",
        @"storage": @"ig_xiongmao",
      },
    };
    for (NSString *argument in directPlayBoxGuests) {
      if (![NSProcessInfo.processInfo.arguments containsObject:argument]) {
        continue;
      }
      NSDictionary<NSString *, NSString *> *guest =
          directPlayBoxGuests[argument];
      [defaults setObject:@"playbox" forKey:AppBoxRuntimeKindKey];
      [defaults setObject:NSUUID.UUID.UUIDString
                   forKey:AppBoxRuntimeLaunchTokenKey];
      [defaults setObject:guest[@"bundle"]
                   forKey:@"AppBoxPlayBoxGuestBundleIdentifier"];
      [defaults setObject:guest[@"storage"]
                   forKey:@"AppBoxPlayBoxGuestStorageIdentifier"];
      [defaults synchronize];
      NSLog(@"APPBOX_PLAYBOX_RUNTIME direct_harness guest=%@",
            guest[@"storage"]);
      break;
    }
    NSString *launchToken = [defaults stringForKey:AppBoxRuntimeLaunchTokenKey];
    NSString *runtimeKind = [defaults stringForKey:AppBoxRuntimeKindKey];
    if (launchToken.length == 0) {
      launchToken = [defaults stringForKey:AppBoxGuestLaunchTokenKey];
      if (launchToken.length > 0) {
        runtimeKind = @"playbox";
      }
    }
    if (launchToken.length == 0 &&
        AppBoxConsumeFreshPlayBoxContinuationMarker()) {
      // The supported HBuilder guest performs one internal relaunch after its
      // resource/bootstrap phase. PBPlayerKit also restores a preferences
      // snapshot during that transition, so this one-use Documents marker is
      // intentionally independent of NSUserDefaults.
      launchToken = NSUUID.UUID.UUIDString;
      runtimeKind = @"playbox";
    }

    // Older builds persisted guest mode forever, which made every normal app
    // launch jump straight into the guest. Guest launch is now a one-shot
    // command: consume it before entering the runtime, so the next AppBox open
    // always returns to the launcher even if the guest crashes.
    [defaults removeObjectForKey:AppBoxGuestModeKey];
    if (launchToken.length > 0) {
      [defaults removeObjectForKey:AppBoxRuntimeLaunchTokenKey];
      [defaults removeObjectForKey:AppBoxGuestLaunchTokenKey];
      [defaults synchronize];
      int result = [runtimeKind isEqualToString:@"flutter"]
          ? AppBoxRunFlutterGuest(argc, argv)
          : AppBoxRunPlayBoxGuest(argc, argv);
      if (result >= 0) {
        return result;
      }
    }
    return UIApplicationMain(argc, argv, nil,
                             NSStringFromClass(NSClassFromString(@"AppBoxHostDelegate")));
  }
}
