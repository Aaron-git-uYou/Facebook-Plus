// The toast pill view: builds and animates the message, glyph and progress
// layouts, and handles tap-to-dismiss and the stop button.

#import "FBPToast.h"
#import "FBPResources.h"

static const CGFloat kToastHeight   = 52.0;
static const CGFloat kToastMinWidth = 160.0;
static const CGFloat kToastPadding  = 14.0;
static const CGFloat kToastRadius   = 26.0;

@interface FBPToastView ()
@property (nonatomic, strong) UILabel *toastLabel;
@property (nonatomic, strong) UIImageView *toastIcon;
@property (nonatomic, strong) UIButton *toastButton;
@property (nonatomic, strong) UIProgressView *toastProgress;
@property (nonatomic, strong) UIActivityIndicatorView *activityIndicator;
@property (nonatomic, copy, nullable) dispatch_block_t stopCompletion;
@property (nonatomic, assign) BOOL isAnimating;
@property (nonatomic, assign, readwrite) BOOL isProcessing;
@property (nonatomic, strong) NSLayoutConstraint *widthConstraint;
@end

@implementation FBPToastView

- (instancetype)init {
    UIBlurEffect *effect = [UIBlurEffect effectWithStyle:UIBlurEffectStyleSystemThickMaterial];
    if ((self = [super initWithEffect:effect])) {
        [self buildInterface];
    }
    return self;
}

- (void)buildInterface {
    self.translatesAutoresizingMaskIntoConstraints = NO;
    self.clipsToBounds = YES;
    self.layer.cornerRadius = kToastRadius;
    self.layer.cornerCurve = kCACornerCurveContinuous;

    UIView *content = self.contentView;

    _toastIcon = [[UIImageView alloc] init];
    _toastIcon.contentMode = UIViewContentModeScaleAspectFit;
    _toastIcon.translatesAutoresizingMaskIntoConstraints = NO;
    _toastIcon.tintColor = UIColor.labelColor;
    [content addSubview:_toastIcon];

    _activityIndicator = [[UIActivityIndicatorView alloc]
        initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleMedium];
    _activityIndicator.translatesAutoresizingMaskIntoConstraints = NO;
    _activityIndicator.hidesWhenStopped = YES;
    [content addSubview:_activityIndicator];

    _toastLabel = [[UILabel alloc] init];
    _toastLabel.font = [UIFont systemFontOfSize:15 weight:UIFontWeightMedium];
    _toastLabel.textColor = UIColor.labelColor;
    _toastLabel.numberOfLines = 1;
    _toastLabel.textAlignment = NSTextAlignmentCenter;
    _toastLabel.adjustsFontSizeToFitWidth = YES;
    _toastLabel.minimumScaleFactor = 0.8;

    // Icon + label as one centred group, so the message sits in the middle of
    // the pill instead of being pushed to one side.
    UIStackView *row = [[UIStackView alloc] initWithArrangedSubviews:@[_toastIcon, _toastLabel]];
    row.axis = UILayoutConstraintAxisHorizontal;
    row.alignment = UIStackViewAlignmentCenter;
    row.spacing = 8;
    row.translatesAutoresizingMaskIntoConstraints = NO;
    [content addSubview:row];

    _toastProgress = [[UIProgressView alloc]
        initWithProgressViewStyle:UIProgressViewStyleDefault];
    _toastProgress.progressTintColor = FBPTintColor();
    _toastProgress.trackTintColor = [UIColor.labelColor colorWithAlphaComponent:0.15];
    _toastProgress.translatesAutoresizingMaskIntoConstraints = NO;
    _toastProgress.hidden = YES;
    [content addSubview:_toastProgress];

    _toastButton = [UIButton buttonWithType:UIButtonTypeSystem];
    [_toastButton setImage:[UIImage fbp_symbolNamed:@"stop.circle" size:22]
                  forState:UIControlStateNormal];
    _toastButton.tintColor = UIColor.labelColor;
    _toastButton.translatesAutoresizingMaskIntoConstraints = NO;
    _toastButton.hidden = YES;
    [_toastButton addTarget:self
                     action:@selector(cancelButtonTapped)
           forControlEvents:UIControlEventTouchUpInside];
    [content addSubview:_toastButton];

    _widthConstraint = [self.widthAnchor constraintGreaterThanOrEqualToConstant:kToastMinWidth];

    [NSLayoutConstraint activateConstraints:@[
        [self.heightAnchor constraintEqualToConstant:kToastHeight],
        _widthConstraint,

        [_toastIcon.widthAnchor constraintEqualToConstant:22],
        [_toastIcon.heightAnchor constraintEqualToConstant:22],

        // The whole icon+label group is centred in the pill.
        [row.centerXAnchor constraintEqualToAnchor:content.centerXAnchor],
        [row.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],
        [row.leadingAnchor constraintGreaterThanOrEqualToAnchor:content.leadingAnchor
                                                        constant:kToastPadding],
        [row.trailingAnchor constraintLessThanOrEqualToAnchor:content.trailingAnchor
                                                     constant:-kToastPadding],

        [_activityIndicator.centerXAnchor constraintEqualToAnchor:_toastIcon.centerXAnchor],
        [_activityIndicator.centerYAnchor constraintEqualToAnchor:_toastIcon.centerYAnchor],

        // Stop button and progress bar (used only by long-running toasts) sit as
        // overlays on the edges, so they never shift the centred message.
        [_toastButton.trailingAnchor constraintEqualToAnchor:content.trailingAnchor
                                                    constant:-kToastPadding],
        [_toastButton.centerYAnchor constraintEqualToAnchor:content.centerYAnchor],

        [_toastProgress.leadingAnchor constraintEqualToAnchor:content.leadingAnchor
                                                     constant:kToastPadding],
        [_toastProgress.trailingAnchor constraintEqualToAnchor:content.trailingAnchor
                                                      constant:-kToastPadding],
        [_toastProgress.bottomAnchor constraintEqualToAnchor:content.bottomAnchor constant:-8],
    ]];

    UITapGestureRecognizer *tap =
        [[UITapGestureRecognizer alloc] initWithTarget:self action:@selector(handleTap)];
    [self addGestureRecognizer:tap];
}

#pragma mark - Public

- (void)showText:(NSString *)text {
    [self showMessage:text success:YES duration:2.0];
}

- (void)showMessage:(NSString *)text success:(BOOL)success {
    [self showMessage:text success:success duration:2.0];
}

- (void)showMessage:(NSString *)text success:(BOOL)success duration:(NSTimeInterval)duration {
    self.isProcessing = NO;
    self.title = text;
    self.toastLabel.text = text;
    self.toastProgress.hidden = YES;
    self.toastButton.hidden = YES;
    [self.activityIndicator stopAnimating];
    self.toastIcon.hidden = NO;
    self.toastIcon.image = [UIImage fbp_symbolNamed:(success ? @"checkmark.circle" : @"xmark.circle")
                                               size:22];
    self.toastIcon.tintColor = success ? UIColor.systemGreenColor : UIColor.systemRedColor;

    [self presentIfNeeded];
    [self hideWithDelay:duration];
}

- (void)showProgressWithText:(NSString *)text
                    progress:(float)progress
                    withStop:(BOOL)withStop
              stopCompletion:(dispatch_block_t)stopCompletion {
    self.isProcessing = YES;
    self.title = text;
    self.stopCompletion = stopCompletion;

    self.toastLabel.text = text;
    self.toastIcon.hidden = YES;
    [self.activityIndicator startAnimating];
    self.toastProgress.hidden = NO;
    [self.toastProgress setProgress:progress animated:NO];
    self.toastButton.hidden = !withStop;

    [self presentIfNeeded];
}

- (void)updateText:(NSString *)text progress:(float)progress {
    [self updateText:text progress:progress animated:YES];
}

- (void)updateText:(NSString *)text progress:(float)progress animated:(BOOL)animated {
    dispatch_async(dispatch_get_main_queue(), ^{
        if (text.length) {
            self.title = text;
            // Percentage is appended rather than replacing the label so the
            // caller does not have to re-format on every statistics callback.
            self.toastLabel.text =
                [NSString stringWithFormat:@"%@: %.0f%%", text, progress * 100.0];
        }
        [self.toastProgress setProgress:progress animated:animated];
    });
}

- (void)hideWithDelay:(NSTimeInterval)delay {
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{
        [self hideWithCompletion:nil];
    });
}

- (void)hideWithCompletion:(dispatch_block_t)completion {
    if (self.isAnimating) return;
    self.isAnimating = YES;

    [UIView animateWithDuration:0.28
                          delay:0
         usingSpringWithDamping:1.0
          initialSpringVelocity:0
                        options:UIViewAnimationOptionCurveEaseIn
                     animations:^{
        self.alpha = 0;
        self.transform = CGAffineTransformMakeScale(0.9, 0.9);
    } completion:^(BOOL finished) {
        [FBPToastManager.shared unregisterToast:self];
        [self removeFromSuperview];
        self.isAnimating = NO;
        if (completion) completion();
    }];
}

#pragma mark - Private

- (void)presentIfNeeded {
    if (self.superview) return;
    self.alpha = 0;
    self.transform = CGAffineTransformMakeScale(0.9, 0.9);
    [FBPToastManager.shared registerToast:self];
    [UIView animateWithDuration:0.32
                          delay:0
         usingSpringWithDamping:0.82
          initialSpringVelocity:0.4
                        options:UIViewAnimationOptionCurveEaseOut
                     animations:^{
        self.alpha = 1;
        self.transform = CGAffineTransformIdentity;
    } completion:nil];
}

- (void)cancelButtonTapped {
    dispatch_block_t stop = self.stopCompletion;
    self.stopCompletion = nil;
    if (stop) stop();
    [self hideWithCompletion:nil];
}

- (void)handleTap {
    if (!self.isProcessing) [self hideWithCompletion:nil];
}

@end
