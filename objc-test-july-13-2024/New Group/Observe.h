//
//  BlockObserver.h
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 30.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

///
/// Base Class
///

@interface BlockObserver : NSObject

/// Define types
typedef id ObservationCallbackBlock;
typedef void (^ObservationCallbackBlockWithNew)(NSObject *newValue);
typedef void (^ObservationCallbackBlockWithOldAndNew)(NSObject *oldValue, NSObject *newValue);

@end

///
/// NSObject Additions
///

@interface NSObject (MFBlockObserver)
- (BlockObserver *)observe:(NSString *)keyPath withBlock:(ObservationCallbackBlockWithNew)block;
- (void)removeBlockObserver:(BlockObserver *)blockObserver;
@end

///
/// Combined Streams
///

@interface BlockObserver (CombinedValueStreamObservation)

+ (void)removeBlockObservers:(NSArray<BlockObserver *> *)observers;

_Pragma("clang assume_null begin")

typedef void (^ObservationCallbackBlockWithLatestArray)(NSArray *_Nonnull latestValues, int updatedIndex); /// Removed this for performance reasons
typedef void (^ObservationCallbackBlockWithLatest)(int updatedIndex, ...);

#define NOB NSObject *_Nullable
typedef void (^ObservationCallbackBlockWithLatest2)(int updatedIndex, NOB v1, NOB v2);
typedef void (^ObservationCallbackBlockWithLatest3)(int updatedIndex, NOB v1, NOB v2, NOB v3);
typedef void (^ObservationCallbackBlockWithLatest4)(int updatedIndex, NOB v1, NOB v2, NOB v3, NOB v4);
typedef void (^ObservationCallbackBlockWithLatest5)(int updatedIndex, NOB v1, NOB v2, NOB v3, NOB v4, NOB v5);
typedef void (^ObservationCallbackBlockWithLatest6)(int updatedIndex, NOB v1, NOB v2, NOB v3, NOB v4, NOB v5, NOB v6);
typedef void (^ObservationCallbackBlockWithLatest7)(int updatedIndex, NOB v1, NOB v2, NOB v3, NOB v4, NOB v5, NOB v6, NOB v7);
typedef void (^ObservationCallbackBlockWithLatest8)(int updatedIndex, NOB v1, NOB v2, NOB v3, NOB v4, NOB v5, NOB v6, NOB v7, NOB v8);
typedef void (^ObservationCallbackBlockWithLatest9)(int updatedIndex, NOB v1, NOB v2, NOB v3, NOB v4, NOB v5, NOB v6, NOB v7, NOB v8, NOB v9);
#undef NOB

+ (NSArray<BlockObserver *> *)observeLatest2:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest2)callback;
+ (NSArray<BlockObserver *> *)observeLatest3:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest3)callback;
+ (NSArray<BlockObserver *> *)observeLatest4:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest4)callback;
+ (NSArray<BlockObserver *> *)observeLatest5:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest5)callback;
+ (NSArray<BlockObserver *> *)observeLatest6:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest6)callback;
+ (NSArray<BlockObserver *> *)observeLatest7:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest7)callback;
+ (NSArray<BlockObserver *> *)observeLatest8:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest8)callback;
+ (NSArray<BlockObserver *> *)observeLatest9:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest9)callback;

@end

#pragma mark - Macros

///
/// Unbox NSValue
///

/// Use like this:
///     `CGRect unboxed = unboxNSValue(CGRect, someBox)`
///
/// Or even like this:
///     `NSString *unboxed = unboxNSValue(NSString*, notABox)`
///     (This behaviour could be useful for building macros on top of this one)
///
/// Useful for KeyValueObservation change notifiations (since those pass around primitive values boxed inside NSValue)
///
/// Note:
///     The last expression is like the 'return value' in this weird ({}) c syntax 
///

#define unboxNSValue_Safe(__unboxedType, __boxedValue) \
({ \
    __unboxedType unboxedValue; \
    if ([__boxedValue isKindOfClass:[NSValue class]]) { \
        [(id)__boxedValue getValue:&unboxedValue]; \
    } else { \
        unboxedValue = (__unboxedType)__boxedValue; \
    } \
    \
    unboxedValue; \
}) \

#define unboxNSValue(__unboxedType, __boxedValue) \
({ \
    __unboxedType unboxedValue; \
    [(id)__boxedValue getValue:&unboxedValue]; \
    unboxedValue; \
}) \


NS_ASSUME_NONNULL_END
