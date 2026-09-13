// First-run welcome / onboarding screen.

#import "FBPlus.h"

NS_ASSUME_NONNULL_BEGIN

/// The onboarding screen. Shown once on first launch, and again on demand from
/// Settings.
@interface FBPWelcomeController : UIViewController

/// Presents only if onboarding has not been shown yet (first launch).
+ (void)presentIfNeeded;

/// Presents unconditionally — used by the "Show welcome screen" settings row.
+ (void)present;

@end

NS_ASSUME_NONNULL_END
