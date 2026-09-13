// Rebinds the SecItem* keychain functions (via fishhook) so every call is pinned
// to the access group probed at launch, letting a re-signed app read and write
// its own keychain.

#import <Security/Security.h>

#import "Header.h"
#import "../../fishhook/fishhook.h"

static OSStatus (*origSecItemAdd)(CFDictionaryRef attributes, CFTypeRef *result);
static OSStatus (*origSecItemCopyMatching)(CFDictionaryRef query, CFTypeRef *result);
static OSStatus (*origSecItemUpdate)(CFDictionaryRef query, CFDictionaryRef attributesToUpdate);
static OSStatus (*origSecItemDelete)(CFDictionaryRef query);

static OSStatus fbpSecItemAdd(CFDictionaryRef attributes, CFTypeRef *result) {
	NSMutableDictionary *mutableAttributes = [(__bridge NSDictionary *)attributes mutableCopy];
	mutableAttributes[(__bridge NSString *)kSecAttrAccessGroup] = accessGroupId;
	return origSecItemAdd((__bridge CFDictionaryRef)mutableAttributes, result);
}

static OSStatus fbpSecItemCopyMatching(CFDictionaryRef query, CFTypeRef *result) {
	NSMutableDictionary *mutableQuery = [(__bridge NSDictionary *)query mutableCopy];
	mutableQuery[(__bridge NSString *)kSecAttrAccessGroup] = accessGroupId;
	return origSecItemCopyMatching((__bridge CFDictionaryRef)mutableQuery, result);
}

static OSStatus fbpSecItemUpdate(CFDictionaryRef query, CFDictionaryRef attributesToUpdate) {
	NSMutableDictionary *mutableQuery = [(__bridge NSDictionary *)query mutableCopy];
	mutableQuery[(__bridge NSString *)kSecAttrAccessGroup] = accessGroupId;
	return origSecItemUpdate((__bridge CFDictionaryRef)mutableQuery, attributesToUpdate);
}

static OSStatus fbpSecItemDelete(CFDictionaryRef query) {
	NSMutableDictionary *mutableQuery = [(__bridge NSDictionary *)query mutableCopy];
	mutableQuery[(__bridge NSString *)kSecAttrAccessGroup] = accessGroupId;
	return origSecItemDelete((__bridge CFDictionaryRef)mutableQuery);
}

void rebindSecFuncs() {
	struct rebinding rebinds[4] = {
		{"SecItemAdd", (void *)fbpSecItemAdd, (void **)&origSecItemAdd},
		{"SecItemCopyMatching", (void *)fbpSecItemCopyMatching, (void **)&origSecItemCopyMatching},
		{"SecItemUpdate", (void *)fbpSecItemUpdate, (void **)&origSecItemUpdate},
		{"SecItemDelete", (void *)fbpSecItemDelete, (void **)&origSecItemDelete}
	};
	// The rebind itself must always run — only the log is debug-gated, so the
	// result is unused in the release build (PILog compiles to a no-op).
	__attribute__((unused)) int result = rebind_symbols(rebinds, 4);
	PILog(@"rebind_symbols result: %d", result);
}
