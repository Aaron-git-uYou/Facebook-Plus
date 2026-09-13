// Filesystem helpers: create a directory on demand, and resolve the app's real
// App-Group container path from its entitlements (via LSBundleProxy).

#import <objc/runtime.h>

#import "Header.h"

BOOL createDirectoryIfNotExists(NSString *path) {
	NSFileManager *fileManager = [NSFileManager defaultManager];
	if ([fileManager fileExistsAtPath:path]) {
		PILog(@"directory already exists: %@", path);
		return YES;
	}

	NSError *error = nil;
	[fileManager createDirectoryAtPath:path
		   withIntermediateDirectories:YES
							attributes:nil
								 error:&error];

	if (error) {
		PILog(@"failed to create directory at path (%@): %@", path, error);
		return NO;
	}

	PILog(@"created directory at path: %@", path);
	return YES;
}

NSURL *getAppGroupPathIfExists() {
	static NSURL *cachedAppGroupPath = nil;
	static dispatch_once_t onceToken;

	dispatch_once(&onceToken, ^{
		PILog(@"fetching app group path...");

		LSBundleProxy *bundleProxy = [objc_getClass("LSBundleProxy") bundleProxyForCurrentProcess];
		if (!bundleProxy) {
			PILog(@"failed to retrieve LSBundleProxy for the current process");
			return;
		}

		NSDictionary *entitlements = bundleProxy.entitlements;
		if (!entitlements || ![entitlements isKindOfClass:[NSDictionary class]]) {
			PILog(@"failed to retrieve entitlements");
			return;
		}

		NSArray *appGroups = entitlements[@"com.apple.security.application-groups"];
		if (!appGroups) {
			PILog(@"no app groups found in entitlements");
			return;
		}

		if (appGroups.count == 0) {
			PILog(@"app group entitlement exists, but no app groups are configured");
			return;
		}

		NSString *appGroupName = [appGroups firstObject];
		PILog(@"app group name: %@", appGroupName);

		NSDictionary *appGroupsPaths = bundleProxy.groupContainerURLs;
		if (!appGroupsPaths || ![appGroupsPaths isKindOfClass:[NSDictionary class]]) {
			PILog(@"failed to retrieve group container URLs");
			return;
		}

		NSURL *ourAppGroupURL = appGroupsPaths[appGroupName];
		if (ourAppGroupURL) {
			cachedAppGroupPath = ourAppGroupURL;
			PILog(@"app group path: %@", cachedAppGroupPath.path);
		} else {
			PILog(@"no path found for app group name: %@", appGroupName);
		}
	});

	return cachedAppGroupPath;
}
