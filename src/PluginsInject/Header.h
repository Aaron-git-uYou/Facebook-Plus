// Sideload compatibility layer. Re-signing an app with a personal certificate
// strips the entitlements it was built against, so its keychain and App-Group
// storage break. This transparently restores both, and keeps CloudKit from
// hard-faulting on an iCloud container the re-signed build can never be granted.
//
// PluginsInject.mm  — constructor: probe the keychain access group, install rebinds
// SecRebinds.xm     — pin SecItem* to that access group via fishhook
// SideloadFix.xm    — redirect CloudKit / App-Group / group NSUserDefaults containers
// Paths.mm          — resolve (or fabricate) the App-Group container path

#import <Foundation/Foundation.h>

// Debug-only logging, compiled out of the release (FINALPACKAGE) build.
#if DEBUG
#define PILog(fmt, ...) NSLog(@"[Facebook Plus] " fmt, ##__VA_ARGS__)
#else
#define PILog(fmt, ...) do {} while (0)
#endif

extern NSString *accessGroupId;
extern NSString *bundleId;

extern void rebindSecFuncs();

extern BOOL createDirectoryIfNotExists(NSString *path);
extern NSURL *getAppGroupPathIfExists();

@interface LSBundleProxy: NSObject
@property(nonatomic, assign, readonly) NSDictionary *entitlements;
@property(nonatomic, assign, readonly) NSDictionary *groupContainerURLs;
+ (instancetype)bundleProxyForCurrentProcess;
@end
