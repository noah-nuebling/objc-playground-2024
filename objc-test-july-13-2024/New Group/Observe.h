//
//  BlockObserver.h
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 30.07.24.
//

#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Typedef

/// Define shorthand
///     If we define the shorthands as NSObject onstead of id the type checker will complain when we try to pass in NSObject subclasses to the callbacks. 
#define NOB id _Nullable // NSObject * _Nullable
#define OB id _Nonnull // NSObject * _Nonnull

/// Basic observation callbacks
typedef id ObservationCallbackBlock;
typedef void (^ObservationCallbackBlockWithNew)(OB newValue);
typedef void (^ObservationCallbackBlockWithOldAndNew)(NOB oldValue, OB newValue);

/// Observe-latest callbacks
typedef void (^ObservationCallbackBlockWithLatest)(int updatedValueIndex, ...);
typedef void (^ObservationCallbackBlockWithLatest2)(int updatedValueIndex, NOB v1, NOB v2);    /// Previously we just passed an array of all the latest values instead of having 9 different methods, but that was a little slower.
typedef void (^ObservationCallbackBlockWithLatest3)(int updatedValueIndex, NOB v1, NOB v2, NOB v3);
typedef void (^ObservationCallbackBlockWithLatest4)(int updatedValueIndex, NOB v1, NOB v2, NOB v3, NOB v4);
typedef void (^ObservationCallbackBlockWithLatest5)(int updatedValueIndex, NOB v1, NOB v2, NOB v3, NOB v4, NOB v5);
typedef void (^ObservationCallbackBlockWithLatest6)(int updatedValueIndex, NOB v1, NOB v2, NOB v3, NOB v4, NOB v5, NOB v6);
typedef void (^ObservationCallbackBlockWithLatest7)(int updatedValueIndex, NOB v1, NOB v2, NOB v3, NOB v4, NOB v5, NOB v6, NOB v7);
typedef void (^ObservationCallbackBlockWithLatest8)(int updatedValueIndex, NOB v1, NOB v2, NOB v3, NOB v4, NOB v5, NOB v6, NOB v7, NOB v8);
typedef void (^ObservationCallbackBlockWithLatest9)(int updatedValueIndex, NOB v1, NOB v2, NOB v3, NOB v4, NOB v5, NOB v6, NOB v7, NOB v8, NOB v9);

/// Undefine shorthand
#undef OB
#undef NOB

#pragma mark - Main Interface

@interface BlockObserver : NSObject
@end

@interface NSObject (MFBlockObserverInterface)

/// Basic observation
///     Note this when using:
///     - CAUTION: If the callbackBlock captures the observedObject or any other object which itself retains the observedObject, that will still create a retain cycle!
///     - The returned BlockObserver  can be used to cancel the observation prematurely.
///     > Otherwise the KVO Observation will be automatically cancelled before the observed object is deallocated. You don't need to manually clean up. If you try to manually cancel the observation after the object has been deallocated or the observation has already been stopped, nothing happens.
///     - If you observe a primitive value such as int or float, it will arrrive in the callback boxed in an NSValue. Use the unboxNSValue() macro to get the underlying primitive.
- (BlockObserver *)observe:(NSString *)keyPath withBlock:(ObservationCallbackBlockWithNew)block;

/// Basic observation but the first invocation of the block will happen when the observed value is first updated instead of immediately.
- (BlockObserver *)observeUpdates:(NSString *)keyPath withBlock:(ObservationCallbackBlockWithNew)block;
@end

@interface BlockObserver (MFBlockObserverInterface)

/// Check state
- (BOOL)isActive;

/// Cancel observation
- (void)cancelObservation;
+ (void)cancelBlockObservations:(NSArray<BlockObserver *> *)observers;

/// Observe latest
///     Note this when using:
///     - CAUTION: If any of the observed objects are retained inside the callbackBlock -> retain cycle!
///     - The callbackBlock will be executed on the thread where the underlying value was changed, there's a thread-lock to ensure that the callbackBlock is not executed multiple times at once.
///     - The returned array of BlockObservers can be used to cancel observation prematurely. If one of the observed objects is deallocated during the observation, the latest value for it will appear as 'nil' in the callback,
///         unless the value is retained somewhere else. In any case, the latestValue passed into the callback will never updated again.
+ (NSArray<BlockObserver *> *)observeLatest:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest)callback;
+ (NSArray<BlockObserver *> *)observeLatest2:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest2)callback;
+ (NSArray<BlockObserver *> *)observeLatest3:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest3)callback;
+ (NSArray<BlockObserver *> *)observeLatest4:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest4)callback;
+ (NSArray<BlockObserver *> *)observeLatest5:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest5)callback;
+ (NSArray<BlockObserver *> *)observeLatest6:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest6)callback;
+ (NSArray<BlockObserver *> *)observeLatest7:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest7)callback;
+ (NSArray<BlockObserver *> *)observeLatest8:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest8)callback;
+ (NSArray<BlockObserver *> *)observeLatest9:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest9)callback;

@end

#pragma mark - Convenience Macro

///
/// Unbox NSValue
///

/// Use like this:
///     `CGRect unboxed = unboxNSValue(CGRect, someNSValue)`

/// Use this inside `ObservationCallbackBlock`s - primitive values like int and float will be passed into the callback boxed in an NSValue.
///
/// Explanation:
///     The last expression is like the 'return value' in this weird ({}) c syntax

#define unboxNSValue(__unboxedType, __boxedValue) \
({ \
    __unboxedType unboxedValue; \
    [(id)__boxedValue getValue:&unboxedValue]; \
    unboxedValue; \
}) \

NS_ASSUME_NONNULL_END
