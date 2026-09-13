// Bottom action sheet: the action model, its content-sized controller, the
// presenter, and a custom detent presentation for older iOS.

#import "FBPlus.h"

NS_ASSUME_NONNULL_BEGIN

/// One row in an action sheet.
///
/// The row renders @c detail above @c title — the detail small and grey on top,
/// the title large underneath.
@interface FBPSheetAction : NSObject

@property (nonatomic, copy) NSString *title;
@property (nonatomic, copy, nullable) NSString *detail;
/// SF Symbol name for the leading glyph.
@property (nonatomic, copy, nullable) NSString *iconName;
@property (nonatomic, assign) BOOL destructive;
@property (nonatomic, copy, nullable) dispatch_block_t handler;

+ (instancetype)actionWithTitle:(NSString *)title
                         detail:(nullable NSString *)detail
                       iconName:(nullable NSString *)iconName
                        handler:(nullable dispatch_block_t)handler;

@end

/// Content-sized bottom sheet listing actions, with a separate Cancel card.
@interface FBPSheetController : UIViewController

- (instancetype)initWithActions:(NSArray<FBPSheetAction *> *)actions
                          title:(nullable NSString *)title;

/// Height the sheet wants, used to drive the detent.
@property (nonatomic, readonly) CGFloat preferredSheetHeight;

@end

@interface FBPSheetPresenter : NSObject

+ (void)presentActions:(NSArray<FBPSheetAction *> *)actions
                 title:(nullable NSString *)title
    fromViewController:(nullable UIViewController *)viewController
            sourceView:(nullable UIView *)sourceView;

/// Best-effort topmost presented controller, for hooks that only have a view.
+ (nullable UIViewController *)topViewController;

@end

/// Fallback half-sheet presentation for iOS < 15, and for the cases where a
/// precise pixel height is wanted that native detents cannot express.
@interface FBPDetentPresentationController : UIPresentationController
@property (nonatomic, assign) CGFloat customHeight;
@end

@interface FBPDetentTransitioningDelegate : NSObject <UIViewControllerTransitioningDelegate>
@property (nonatomic, assign) CGFloat customHeight;
@end

NS_ASSUME_NONNULL_END
