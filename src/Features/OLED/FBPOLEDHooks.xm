// OLED Dark Mode: turn Facebook's whole UI true-black.
//
// When the toggle is on, every app window is forced to the dark interface style
// (so the user does not have to enable Facebook's own dark mode), and every dark
// surface in the view tree is repainted pure black. Because the app is forced
// dark, the repaint runs unconditionally while the toggle is on — there is no
// separate "is the app dark" check that could go stale and leave some surfaces
// grey while others turn black.
//
// Facebook paints backgrounds at many levels, and the two surfaces that used to
// stay grey — the top app header and the profile's "Add to story / Edit profile"
// panel — are painted by mechanisms a plain -setBackgroundColor: hook never sees.
// A radare2/r2pipe walk of FBSharedFramework showed why:
//
//   * FBMovableNavigationBarView (the app header) sets nothing on its own view.
//     Its grey lives on child views (_fakeNavigationBar, _replacementNavigationBar
//     which is a real UINavigationBar drawn through UINavigationBarAppearance /
//     a UIVisualEffectView blur), a fade CAGradientLayer (_extraGradientHeight),
//     and a raw CALayer (FBNavigationBar._statusBarBackground). None of these is
//     the view's own -backgroundColor, so a plain -backgroundColor hook caught it
//     only intermittently, which produced the flickering header.
//
//   * ComponentKit cards (the profile panel) paint their rounded background onto
//     a CAGradientLayer / CAShapeLayer / plain CALayer added as a *sublayer*, not
//     onto the view's -backgroundColor, so -setBackgroundColor: never fires.
//
// So in addition to the -backgroundColor path, the tweak (1) resolves dynamic
// colours against a forced-dark trait collection before judging darkness —
// removing the timing dependence — (2) sweeps each view's own sublayers
// (gradient/shape/plain) and blackens the dark ones, and (3) hooks
// FBMovableNavigationBarView directly to blacken its header sub-tree (blur,
// UINavigationBar, gradients) while leaving genuinely coloured accents and photos
// alone.

#import "FBPlus.h"
#import "FBPPrefs.h"
#import "FBPDiagnostics.h"
#import "FBPHeaders.h"

#import <QuartzCore/QuartzCore.h>
#import <objc/runtime.h>

/// Cached toggle state, refreshed on the settings-changed notification so the hot
/// path never touches NSUserDefaults.
static BOOL gOLEDEnabled = NO;

static void FBPRefreshOLED(void) { gOLEDEnabled = FBPEnabled(FBPKeyOLED); }

#pragma mark - Colour judgement

/// A dark trait collection every dynamic colour is resolved against. Facebook's
/// backgrounds are dynamic UIColors; resolving them explicitly (instead of relying
/// on whatever the current trait environment happens to be) is what makes the
/// header deterministic rather than intermittently dark.
static UITraitCollection *FBPDarkTraits(void) {
    static UITraitCollection *traits = nil;
    static dispatch_once_t once;
    dispatch_once(&once, ^{
        if (@available(iOS 13.0, *)) {
            traits = [UITraitCollection
                traitCollectionWithUserInterfaceStyle:UIUserInterfaceStyleDark];
        }
    });
    return traits;
}

/// Resolves a (possibly dynamic) colour to its concrete dark-mode value.
static UIColor *FBPResolve(UIColor *color) {
    if (!color) return color;
    if (@available(iOS 13.0, *)) {
        UITraitCollection *traits = FBPDarkTraits();
        if (traits) {
            @try {
                UIColor *resolved = [color resolvedColorWithTraitCollection:traits];
                if (resolved) return resolved;
            } @catch (__unused NSException *e) {}
        }
    }
    return color;
}

/// YES for an opaque-ish background that should be deepened to black. A grey
/// surface (Facebook's base *and* its lighter elevated cards) counts up to a
/// mid-grey; a coloured surface only counts when genuinely dark, so accent
/// controls like the blue buttons keep their colour.
static BOOL FBPColorIsDark(UIColor *color) {
    if (!color) return NO;
    CGFloat r = 0, g = 0, b = 0, a = 0;
    if ([color getRed:&r green:&g blue:&b alpha:&a]) {
        if (a < 0.2) return NO;
        CGFloat mx = MAX(r, MAX(g, b)), mn = MIN(r, MIN(g, b));
        CGFloat luma = 0.299 * r + 0.587 * g + 0.114 * b;
        return (mx - mn) < 0.12 ? (luma < 0.48) : (luma < 0.20);
    }
    CGFloat w = 0, wa = 0;
    if ([color getWhite:&w alpha:&wa]) {
        if (wa < 0.2) return NO;
        return w < 0.48;
    }
    return NO;
}

/// Darkness test for a CGColorRef (layer colours are always CGColor and already
/// concrete, so no dynamic resolution is needed).
static BOOL FBPCGColorIsDark(CGColorRef cg) {
    if (!cg) return NO;
    return FBPColorIsDark([UIColor colorWithCGColor:cg]);
}

/// The tweak's own UI keeps its own colours.
static BOOL FBPOLEDSkip(UIView *view) {
    return [NSStringFromClass([view class]) hasPrefix:@"FBP"];
}

#pragma mark - Layer sweeping

/// Black that keeps the source colour's alpha. A translucent scrim — an alert's
/// dimming view, a bottom-sheet backdrop — must stay translucent; forcing it to
/// opaque black would turn it into a solid curtain, hiding everything behind a
/// popup in OLED mode. Opaque surfaces (alpha 1) still become solid black, so the
/// rest of the app is unchanged.
static UIColor *FBPBlackKeepingAlpha(UIColor *color) {
    CGFloat alpha = color ? CGColorGetAlpha(color.CGColor) : 1.0;
    return [UIColor colorWithWhite:0.0 alpha:alpha];
}
static CGColorRef FBPBlackCGKeepingAlpha(CGColorRef cg) {
    CGFloat alpha = cg ? CGColorGetAlpha(cg) : 1.0;
    return [UIColor colorWithWhite:0.0 alpha:alpha].CGColor;
}

/// Blackens the dark colours a view paints *directly onto its own layer's
/// sublayers* — the gradient/shape/plain CALayers ComponentKit uses for rounded
/// card backgrounds and Facebook uses for the header fade and status-bar strip.
/// Layers that merely back a subview are skipped: that subview repaints itself.
static void FBPBlackenSublayers(CALayer *layer) {
    NSArray<CALayer *> *sublayers = layer.sublayers;
    if (sublayers.count == 0) return;
    for (CALayer *sub in [sublayers copy]) {
        if ([sub.delegate isKindOfClass:UIView.class]) continue;   // subview's own layer

        if ([sub isKindOfClass:CAGradientLayer.class]) {
            CAGradientLayer *gradient = (CAGradientLayer *)sub;
            NSArray *colors = gradient.colors;
            BOOL anyDark = NO;
            for (id entry in colors) {
                if (FBPCGColorIsDark((__bridge CGColorRef)entry)) { anyDark = YES; break; }
            }
            if (anyDark && colors.count) {
                NSMutableArray *black = [NSMutableArray arrayWithCapacity:colors.count];
                for (id entry in colors) {
                    [black addObject:(__bridge id)FBPBlackCGKeepingAlpha(
                                         (__bridge CGColorRef)entry)];
                }
                gradient.colors = black;
            }
            continue;
        }
        if ([sub isKindOfClass:CAShapeLayer.class]) {
            CAShapeLayer *shape = (CAShapeLayer *)sub;
            if (FBPCGColorIsDark(shape.fillColor))
                shape.fillColor = FBPBlackCGKeepingAlpha(shape.fillColor);
            if (FBPCGColorIsDark(shape.backgroundColor))
                shape.backgroundColor = FBPBlackCGKeepingAlpha(shape.backgroundColor);
            continue;
        }
        if (FBPCGColorIsDark(sub.backgroundColor))
            sub.backgroundColor = FBPBlackCGKeepingAlpha(sub.backgroundColor);
    }
}

#pragma mark - Header (FBMovableNavigationBarView) helpers

/// Opaque black appearance for the real UINavigationBar the header hosts
/// (_replacementNavigationBar). Its background is drawn through
/// UINavigationBarAppearance / _UIBarBackground (a blur), not -backgroundColor,
/// so the appearance objects must be reconfigured and the blur flattened.
static void FBPBlackNavigationBar(UINavigationBar *bar) {
    if (!bar) return;
    bar.translucent = NO;
    bar.barTintColor = UIColor.blackColor;
    bar.backgroundColor = UIColor.blackColor;
    if (@available(iOS 13.0, *)) {
        UINavigationBarAppearance *appearance = [[UINavigationBarAppearance alloc] init];
        [appearance configureWithOpaqueBackground];
        appearance.backgroundColor = UIColor.blackColor;
        appearance.backgroundEffect = nil;
        appearance.shadowColor = UIColor.clearColor;
        appearance.shadowImage = [[UIImage alloc] init];
        bar.standardAppearance = appearance;
        bar.compactAppearance = appearance;
        bar.scrollEdgeAppearance = appearance;
        if (@available(iOS 15.0, *)) bar.compactScrollEdgeAppearance = appearance;
    }
    // Flatten the _UIBarBackground blur that sits behind the bar's content.
    for (UIView *sub in bar.subviews) {
        if ([NSStringFromClass(sub.class) containsString:@"BarBackground"]) {
            sub.backgroundColor = UIColor.blackColor;
            for (UIView *inner in sub.subviews) {
                inner.backgroundColor = UIColor.blackColor;
                if ([inner isKindOfClass:UIVisualEffectView.class]) {
                    ((UIVisualEffectView *)inner).contentView.backgroundColor =
                        UIColor.blackColor;
                }
            }
        }
    }
}

/// Walks the header's sub-tree and blackens every grey surface it finds — dark
/// view backgrounds, dark layer/gradient/shape colours, the hosted UINavigationBar
/// and any blur — while leaving photos (nil/clear backgrounds) and coloured
/// accents untouched, so the profile cover and the blue "Add to story" button
/// keep their look.
static void FBPBlackenHeaderTree(UIView *view, int depth) {
    if (!view || depth > 12) return;
    for (UIView *sub in [view.subviews copy]) {
        if (FBPOLEDSkip(sub)) continue;

        if ([sub isKindOfClass:UINavigationBar.class]) {
            FBPBlackNavigationBar((UINavigationBar *)sub);
        } else if ([sub isKindOfClass:UIVisualEffectView.class]) {
            // A blur in the header reads as grey; cover it flat black.
            sub.backgroundColor = UIColor.blackColor;
            ((UIVisualEffectView *)sub).contentView.backgroundColor = UIColor.blackColor;
            FBPBlackenSublayers(sub.layer);
            continue;   // don't recurse into the effect view's content
        } else {
            if (FBPColorIsDark(FBPResolve(sub.backgroundColor))) {
                sub.backgroundColor = FBPBlackKeepingAlpha(sub.backgroundColor);
            }
            if (FBPCGColorIsDark(sub.layer.backgroundColor)) {
                sub.layer.backgroundColor =
                    FBPBlackCGKeepingAlpha(sub.layer.backgroundColor);
            }
        }
        FBPBlackenSublayers(sub.layer);
        FBPBlackenHeaderTree(sub, depth + 1);
    }
}

#pragma mark - Forced dark appearance

/// Forces every app window to the dark interface style while OLED is on (and
/// releases the override when off), so the toggle alone turns the app dark.
/// Applied only on discrete events (never during layout) to avoid flicker.
static void FBPApplyForcedAppearance(void) {
    if (@available(iOS 13.0, *)) {
        UIUserInterfaceStyle want = gOLEDEnabled ? UIUserInterfaceStyleDark
                                                 : UIUserInterfaceStyleUnspecified;
        for (UIScene *scene in UIApplication.sharedApplication.connectedScenes) {
            if (![scene isKindOfClass:UIWindowScene.class]) continue;
            for (UIWindow *window in ((UIWindowScene *)scene).windows) {
                if ([NSStringFromClass(window.class) hasPrefix:@"FBP"]) continue;
                if (window.overrideUserInterfaceStyle != want) {
                    window.overrideUserInterfaceStyle = want;
                }
            }
        }
    }
}

#pragma mark - Hooks

%group FBPOLEDGlobal

// Force new/key windows dark while OLED is on.
%hook UIWindow
- (void)becomeKeyWindow {
    %orig;
    if (@available(iOS 13.0, *)) {
        if (gOLEDEnabled && ![NSStringFromClass(self.class) hasPrefix:@"FBP"] &&
            self.overrideUserInterfaceStyle != UIUserInterfaceStyleDark) {
            self.overrideUserInterfaceStyle = UIUserInterfaceStyleDark;
        }
    }
}
%end

%hook UIView

- (void)setBackgroundColor:(UIColor *)color {
    if (gOLEDEnabled && !FBPOLEDSkip(self) && FBPColorIsDark(FBPResolve(color))) {
        %orig(FBPBlackKeepingAlpha(color));
        return;
    }
    %orig(color);
}

- (void)layoutSubviews {
    %orig;
    if (!gOLEDEnabled || FBPOLEDSkip(self)) return;

    UIColor *bg = self.backgroundColor;
    if (bg) {
        // Views that paint through -backgroundColor (dynamic colours resolved).
        if (FBPColorIsDark(FBPResolve(bg))) self.backgroundColor = FBPBlackKeepingAlpha(bg);
    } else if (FBPCGColorIsDark(self.layer.backgroundColor)) {
        // ComponentKit cards that paint straight onto their own layer.
        self.layer.backgroundColor = FBPBlackCGKeepingAlpha(self.layer.backgroundColor);
    }

    // Cards / fades that paint onto a sublayer (gradient, shape or plain CALayer)
    // rather than the view or its own layer background — the profile panel and the
    // header fade. Cheap: most views have no sublayers.
    FBPBlackenSublayers(self.layer);
}

%end

%hook UITableView
- (void)setBackgroundColor:(UIColor *)color {
    if (gOLEDEnabled && !FBPOLEDSkip(self) && FBPColorIsDark(FBPResolve(color))) {
        %orig(FBPBlackKeepingAlpha(color));
        return;
    }
    %orig(color);
}
%end

%hook UITableViewCell
- (void)setBackgroundColor:(UIColor *)color {
    if (gOLEDEnabled && !FBPOLEDSkip(self) && FBPColorIsDark(FBPResolve(color))) {
        %orig(FBPBlackKeepingAlpha(color));
        return;
    }
    %orig(color);
}
%end

%hook UICollectionView
- (void)setBackgroundColor:(UIColor *)color {
    if (gOLEDEnabled && !FBPOLEDSkip(self) && FBPColorIsDark(FBPResolve(color))) {
        %orig(FBPBlackKeepingAlpha(color));
        return;
    }
    %orig(color);
}
%end

// The app header. It paints nothing on its own view; the grey lives on child
// views, a hosted UINavigationBar, a blur and gradients — so blacken the sub-tree
// on every layout pass while OLED is on. This is what stops the header flickering
// between grey and black.
%hook FBMovableNavigationBarView
- (void)layoutSubviews {
    %orig;
    if (!gOLEDEnabled) return;
    if (FBPColorIsDark(FBPResolve(self.backgroundColor))) {
        self.backgroundColor = FBPBlackKeepingAlpha(self.backgroundColor);
    }
    if (FBPCGColorIsDark(self.layer.backgroundColor)) {
        self.layer.backgroundColor = FBPBlackCGKeepingAlpha(self.layer.backgroundColor);
    }
    FBPBlackenSublayers(self.layer);
    FBPBlackenHeaderTree(self, 0);
}
%end

%end // FBPOLEDGlobal

void FBPInitOLEDHooks(void) {
    FBPRefreshOLED();

    // Toggling OLED in settings immediately forces (or releases) the dark
    // appearance; the layout hooks then repaint on the next pass.
    [NSNotificationCenter.defaultCenter
        addObserverForName:FBPSettingsDidChangeNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note) {
        FBPRefreshOLED();
        FBPApplyForcedAppearance();
    }];

    // Re-assert the forced appearance on foreground and shortly after launch.
    [NSNotificationCenter.defaultCenter
        addObserverForName:UIApplicationDidBecomeActiveNotification
                    object:nil
                     queue:NSOperationQueue.mainQueue
                usingBlock:^(NSNotification *note) { FBPApplyForcedAppearance(); }];
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(2.0 * NSEC_PER_SEC)),
                   dispatch_get_main_queue(), ^{ FBPApplyForcedAppearance(); });

    FBP_ONCE(gOLED) { %init(FBPOLEDGlobal); }
    [FBPDiagnostics.shared recordGroup:@"FBPOLED" installed:YES detail:nil];
}
