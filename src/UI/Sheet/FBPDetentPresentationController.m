// Custom fixed-height sheet presentation with a tap-to-dismiss dimming view,
// used as the fallback where native detents are unavailable.

#import "FBPSheet.h"

@interface FBPDetentPresentationController ()
@property (nonatomic, strong) UIView *dimmingView;
@end

@implementation FBPDetentPresentationController

- (instancetype)initWithPresentedViewController:(UIViewController *)presented
                       presentingViewController:(UIViewController *)presenting {
    if ((self = [super initWithPresentedViewController:presented
                             presentingViewController:presenting])) {
        _customHeight = 320.0;
        _dimmingView = [[UIView alloc] init];
        _dimmingView.backgroundColor = [UIColor.blackColor colorWithAlphaComponent:0.4];
        _dimmingView.alpha = 0;

        UITapGestureRecognizer *tap =
            [[UITapGestureRecognizer alloc] initWithTarget:self
                                                    action:@selector(dismissController)];
        [_dimmingView addGestureRecognizer:tap];
    }
    return self;
}

- (CGRect)frameOfPresentedViewInContainerView {
    CGRect bounds = self.containerView.bounds;
    CGFloat height = MIN(self.customHeight, CGRectGetHeight(bounds) * 0.9);
    return CGRectMake(0,
                      CGRectGetHeight(bounds) - height,
                      CGRectGetWidth(bounds),
                      height);
}

- (void)presentationTransitionWillBegin {
    self.dimmingView.frame = self.containerView.bounds;
    self.dimmingView.autoresizingMask =
        UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    [self.containerView insertSubview:self.dimmingView atIndex:0];

    self.presentedView.layer.cornerRadius = 20.0;
    self.presentedView.layer.cornerCurve = kCACornerCurveContinuous;
    self.presentedView.layer.maskedCorners =
        kCALayerMinXMinYCorner | kCALayerMaxXMinYCorner;
    self.presentedView.clipsToBounds = YES;

    id<UIViewControllerTransitionCoordinator> coordinator =
        self.presentedViewController.transitionCoordinator;
    if (coordinator) {
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
            self.dimmingView.alpha = 1;
        } completion:nil];
    } else {
        self.dimmingView.alpha = 1;
    }
}

- (void)dismissalTransitionWillBegin {
    id<UIViewControllerTransitionCoordinator> coordinator =
        self.presentedViewController.transitionCoordinator;
    if (coordinator) {
        [coordinator animateAlongsideTransition:^(id<UIViewControllerTransitionCoordinatorContext> ctx) {
            self.dimmingView.alpha = 0;
        } completion:nil];
    } else {
        self.dimmingView.alpha = 0;
    }
}

- (void)dismissController {
    [self.presentedViewController dismissViewControllerAnimated:YES completion:nil];
}

@end

@implementation FBPDetentTransitioningDelegate

- (UIPresentationController *)
    presentationControllerForPresentedViewController:(UIViewController *)presented
                            presentingViewController:(UIViewController *)presenting
                                sourceViewController:(UIViewController *)source {
    FBPDetentPresentationController *controller =
        [[FBPDetentPresentationController alloc] initWithPresentedViewController:presented
                                                       presentingViewController:presenting];
    controller.customHeight = self.customHeight;
    return controller;
}

@end
