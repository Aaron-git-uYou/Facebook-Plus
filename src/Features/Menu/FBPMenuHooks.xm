// Menu (the "See more" / bookmarks tab): diagnostics for section removal.
//
// The goal is to remove the server-driven "Upgrades" and "Also from Meta"
// sections. That menu is a Navigation Menu Experience (NME) surface: each row is
// an FBBookmarkMenuItem carrying a stable -sectionID (e.g. fb_bookmark_also_from_
// meta), but the section titles and grouping come from the server, and the
// concrete data-source that assembles the sections could not be pinned down from
// static analysis of a 159 MB framework alone.
//
// This build is therefore instrumentation only: it records every menu item with
// its sectionID / bookmarkID / displayName, and dumps the fully-built menu view
// tree once the items settle. Exporting Settings -> Diagnostics after opening the
// menu gives the exact sectionIDs to block and the concrete cell / section-header
// classes to hook — everything a later build needs to implement the removal
// safely.

#import "FBPlus.h"
#import "FBPDiagnostics.h"

#import <objc/runtime.h>

@interface FBBookmarkMenuItem : NSObject
- (NSString *)sectionID;
- (NSString *)bookmarkID;
- (NSString *)displayName;
@end

/// Dumps the current screen ~1s after the last menu item is built, so the capture
/// catches the fully-assembled menu no matter which controller backs it. Every
/// new burst of items (each time the menu opens) re-arms it.
static NSInteger gMenuDumpGeneration = 0;
static void FBPMenuScheduleScreenDump(void) {
    NSInteger generation = ++gMenuDumpGeneration;
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(1.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        if (generation != gMenuDumpGeneration) return;   // more items arrived; wait
        [FBPDiagnostics.shared captureCurrentScreen];
    });
}

%group FBPMenuDiag

%hook FBBookmarkMenuItem

- (id)initWithBookmark:(id)bookmark {
    id item = %orig;
    @try {
        static NSInteger logged = 0;
        if (logged < 300) {
            logged += 1;
            NSString *section = [item respondsToSelector:@selector(sectionID)]
                ? [item sectionID] : nil;
            NSString *bookmarkID = [item respondsToSelector:@selector(bookmarkID)]
                ? [item bookmarkID] : nil;
            NSString *name = [item respondsToSelector:@selector(displayName)]
                ? [item displayName] : nil;
            [FBPDiagnostics.shared log:@"menu"
                                 format:@"item  section=%@  id=%@  name=%@",
                section, bookmarkID, name];
        }
        FBPMenuScheduleScreenDump();
    } @catch (__unused NSException *e) {}
    return item;
}

%end

%end // FBPMenuDiag

void FBPInitMenuHooks(void) {
    if (objc_getClass("FBBookmarkMenuItem")) {
        FBP_ONCE(gMenuDiag) { %init(FBPMenuDiag); }
        [FBPDiagnostics.shared recordGroup:@"FBPMenuDiag" installed:YES detail:nil];
    } else {
        FBPLog(@"FBBookmarkMenuItem not found — menu diagnostics disabled");
    }
}
