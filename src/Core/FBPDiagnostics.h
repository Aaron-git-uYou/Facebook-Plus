// In-memory diagnostics log recording hook installs, events, and view-tree
// dumps, exportable as a single .txt from Settings.

#import "FBPlus.h"

NS_ASSUME_NONNULL_BEGIN

/// The tweak's own log, exportable from Settings → Diagnostics.
///
/// Facebook loads most of its frameworks on demand, so which hooks are live
/// depends on where the user has been. On a sideloaded build there is no
/// console and no debugger, so the tweak has to be able to describe its own
/// state — otherwise "the button isn't showing" can only be guessed at.
///
/// Everything is kept in memory and mirrored to a file under Caches, so a full
/// session can be exported as a single .txt through the share sheet.
@interface FBPDiagnostics : NSObject

@property (class, readonly) FBPDiagnostics *shared;

#pragma mark - Recording

/// A hook group either installed or was skipped, with the reason.
- (void)recordGroup:(NSString *)group installed:(BOOL)installed detail:(nullable NSString *)detail;

/// A line in the log. @c category groups related lines: "reels", "story", …
- (void)log:(NSString *)category format:(NSString *)format, ... NS_FORMAT_FUNCTION(2, 3);

/// Convenience for the common case.
- (void)recordEvent:(NSString *)format, ... NS_FORMAT_FUNCTION(1, 2);

/// Dumps a view tree into the log — class names, frames, hidden/alpha, tags and
/// accessibility identifiers.
///
/// This is the single most useful entry here: it shows which of Facebook's view
/// classes are actually on screen and where — precisely what static analysis
/// cannot reveal.
- (void)dumpViewTree:(nullable UIView *)view label:(NSString *)label;

/// Same, but only the first time for a given label, so a per-layout call site
/// does not flood the log.
- (void)dumpViewTreeOnce:(nullable UIView *)view label:(NSString *)label;

/// Dumps whatever is currently on screen, from the key window down.
- (void)captureCurrentScreen;

#pragma mark - Reading

- (BOOL)checkClass:(NSString *)name;
- (NSArray<NSDictionary<NSString *, NSString *> *> *)groupReport;
- (NSArray<NSString *> *)eventLog;

/// The whole session as one text document.
- (NSString *)report;

/// Writes @c report to a .txt in Caches and returns it, for the share sheet.
- (nullable NSURL *)exportToFile;

- (void)clear;

@end

NS_ASSUME_NONNULL_END
