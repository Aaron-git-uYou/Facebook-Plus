// Main settings screen controller interface.

#import "FBPlus.h"

NS_ASSUME_NONNULL_BEGIN

/// Plain UIViewController rather than UITableViewController: the header card is
/// a sibling of the table, so content never scrolls underneath it.
@interface FBPSettingsController : UIViewController

/// Presents the settings sheet on the topmost controller.
+ (void)presentFromViewController:(nullable UIViewController *)viewController;

@end

NS_ASSUME_NONNULL_END
