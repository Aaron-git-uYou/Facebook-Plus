// Meta Facebook Plus: preview the paid subscriber features in the UI without
// subscribing.
//
// Facebook gates its "Facebook Plus" subscriber perks — story previews, story
// extend / rewatch, superlikes, "who viewed my story" search, custom app icons
// and themes, branded threads, and the Meta AI quotas (image generation,
// Imagine video, think-harder) — behind one benefit checker,
// FBSubsBenefitStatusChecker. It is a Swift class living in FBSharedFramework;
// every "is this perk unlocked?" call in the app funnels through its
// -isBenefitActiveWithBenefitType: (Swift `isBenefitActive(benefitType:)`),
// which takes a SUBSXFBNMESubscriptionApplicationBenefitTypeEnum and returns a
// BOOL. Forcing that to YES makes the whole Plus UI appear as though the perk
// were active — the same single-gate approach IGFormat uses for Instagram Plus
// (it hooks the analogous IGConsumerSubsService).
//
// This only unlocks the *client* gate, so it previews the interface: Facebook's
// servers still validate on use, so anything that round-trips (an actual AI
// generation, a server-persisted benefit) will not be granted by this alone.
// It is off by default and cached on the hot path like the other toggles.

#import "FBPlus.h"
#import "FBPPrefs.h"
#import "FBPDiagnostics.h"

#import <objc/runtime.h>

/// Cached toggle, refreshed on the settings-changed notification so the checker
/// (called very frequently while laying out feed / stories / profile) never
/// touches NSUserDefaults.
static BOOL gPlusEnabled = NO;

static void FBPRefreshPlus(void) { gPlusEnabled = FBPEnabled(FBPKeyMetaPlus); }

// FBSubsBenefitStatusChecker is a Swift class, so it is hooked under a
// placeholder name that is bound to the resolved runtime class in %init below.
%group FBPMetaPlus

%hook FBPSubsBenefitStatusChecker

// The one gate every Plus feature consults. The argument is the benefit-type
// enum (an NSInteger under the hood); every type is granted while the toggle is
// on, which is exactly "preview all Facebook Plus features".
- (BOOL)isBenefitActiveWithBenefitType:(NSInteger)benefitType {
    if (gPlusEnabled) return YES;
    return %orig;
}

// A second entry point present on the class in some builds; hooked defensively.
// If a build does not implement it, Logos simply does not install this one.
- (BOOL)isBenefitActive:(NSInteger)benefitType {
    if (gPlusEnabled) return YES;
    return %orig;
}

%end

%end // FBPMetaPlus

void FBPInitPlusHooks(void) {
    FBPRefreshPlus();

    [NSNotificationCenter.defaultCenter
        addObserverForName:FBPSettingsDidChangeNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note) { FBPRefreshPlus(); }];

    // Swift runtime name is _TtC<n><module><n><class>, and for this class the
    // module and class names are identical. `NSClassFromString` also accepts the
    // demangled Module.Class form; a plain ObjC class is tried last in case a
    // future build renames it.
    Class checker =
        NSClassFromString(@"_TtC26FBSubsBenefitStatusChecker26FBSubsBenefitStatusChecker")
        ?: NSClassFromString(@"FBSubsBenefitStatusChecker.FBSubsBenefitStatusChecker")
        ?: objc_getClass("FBSubsBenefitStatusChecker");

    if (checker) {
        FBP_ONCE(gMetaPlus) { %init(FBPMetaPlus, FBPSubsBenefitStatusChecker = checker); }
        [FBPDiagnostics.shared recordGroup:@"FBPMetaPlus" installed:YES
                                    detail:NSStringFromClass(checker)];
    } else {
        [FBPDiagnostics.shared recordGroup:@"FBPMetaPlus" installed:NO
                                    detail:@"FBSubsBenefitStatusChecker not found"];
    }
}
