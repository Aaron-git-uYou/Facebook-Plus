// Non-key window that hosts the toasts above the app and passes through every
// touch that is not on a toast.

#import "FBPToast.h"

@implementation FBPToastWindow

+ (UIWindow *)appKeyWindow {
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if (scene.activationState != UISceneActivationStateForegroundActive) continue;
        if (![scene isKindOfClass:UIWindowScene.class]) continue;
        for (UIWindow *window in ((UIWindowScene *)scene).windows) {
            if (window.isKeyWindow) return window;
        }
    }
    // Fall back to any window at all — better a misplaced toast than none.
    for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
        if ([scene isKindOfClass:UIWindowScene.class]) {
            UIWindow *first = ((UIWindowScene *)scene).windows.firstObject;
            if (first) return first;
        }
    }
    return nil;
}

- (instancetype)initWithWindowScene:(UIWindowScene *)windowScene {
    if ((self = [super initWithWindowScene:windowScene])) {
        self.backgroundColor = UIColor.clearColor;
        self.windowLevel = UIWindowLevelAlert + 100;
        self.userInteractionEnabled = YES;
        self.rootViewController = [[UIViewController alloc] init];
        self.rootViewController.view.backgroundColor = UIColor.clearColor;
    }
    return self;
}

// Never steal first responder from the app.
- (BOOL)canBecomeKeyWindow { return NO; }
- (BOOL)_canBecomeKeyWindow { return NO; }

// Leave status bar appearance and rotation ownership with the app.
- (BOOL)shouldAffectStatusBarAppearance { return NO; }
- (BOOL)_windowControlsStatusBarOrientation { return NO; }

- (void)makeKeyAndVisible {
    // Visible, but not key.
    self.hidden = NO;
}

/// Pass through every touch that is not on an actual toast, so the window does
/// not swallow interaction with Facebook underneath it.
- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event {
    UIView *hit = [super hitTest:point withEvent:event];
    if (hit == self || hit == self.rootViewController.view) return nil;
    return hit;
}

@end
