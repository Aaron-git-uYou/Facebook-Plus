// App icon picker controller interface.

#import <UIKit/UIKit.h>

NS_ASSUME_NONNULL_BEGIN

/// Picker for Facebook's built-in alternate app icons.
///
/// Facebook already ships a set of alternate icons in its own Info.plist
/// (Chill, Dreamy, Fab, Fierce, Lovey, Vaporwave), so switching to one needs no
/// repackaging — the system loads them straight from the app bundle.
@interface FBPAppIconController : UITableViewController
@end

NS_ASSUME_NONNULL_END
