//
//  BlockObserver.h
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 30.07.24.
//

#import <Foundation/Foundation.h>

///
/// This file provides a simple block-based API for observing Key-Value-Observation-compliant objects.
/// It consists of 4 core methods:
///
///    Simple observation:
///         ```
///         BlockObserver *buttonObserver = [button observe:@"value" withBlock:^(NSString *newValue) {
///             otherValue = [newValue stringByAppendingString:@"Hello from KVO block!"]
///             self.something = value;
///         }];
///         ```
///
///    Cancel observation:
///         ```
///         [buttonObserver cancelObservation];
///         ```
///
///    Observe latest:
///         ```
///         NSArray *observers = [BlockObserver observeLatest2:@[@[button, @"value"], @[slider, @"doubleValue"]] withBlock: ^(int updatedValueIndex, NSValue *v0, NSValue *v1) {
///             int buttonValue = unboxNSValue(int, v0);
///             double sliderValue = unboxNSValue(int, v1);
///             ...
///         }];
///         ```
///
///     Cancel observeLatest:
///         ```
///         [BlockObserver cancelObservations:observers];
///         ```

NS_ASSUME_NONNULL_BEGIN

#pragma mark - Typedef

#define nullid id _Nullable

/// Basic observation callbacks
typedef id ObservationCallbackBlock;
typedef void (^ObservationCallbackBlockWithNew)(id newValue);
typedef void (^ObservationCallbackBlockWithOldAndNew)(nullid oldValue, id newValue);

/// Observe-latest callbacks
typedef id ObservationCallbackBlockWithLatest;
typedef void (^ObservationCallbackBlockWithLatest2)(int updatedValueIndex, nullid v0, nullid v1);
typedef void (^ObservationCallbackBlockWithLatest3)(int updatedValueIndex, nullid v0, nullid v1, nullid v2);
typedef void (^ObservationCallbackBlockWithLatest4)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3);
typedef void (^ObservationCallbackBlockWithLatest5)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3, nullid v4);
typedef void (^ObservationCallbackBlockWithLatest6)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3, nullid v4, nullid v5);
typedef void (^ObservationCallbackBlockWithLatest7)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3, nullid v4, nullid v5, nullid v6);
typedef void (^ObservationCallbackBlockWithLatest8)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3, nullid v4, nullid v5, nullid v6, nullid v7);
typedef void (^ObservationCallbackBlockWithLatest9)(int updatedValueIndex, nullid v0, nullid v1, nullid v2, nullid v3, nullid v4, nullid v5, nullid v6, nullid v7, nullid v8);

#undef nullid

#pragma mark - Main Interface

@interface BlockObserver : NSObject
@end

@interface NSObject (MFBlockObserverInterface)

/// Basic observation
///     Note this when using:
///     - Caution: If the callbackBlock captures the observedObject or any other object which itself retains the observedObject, that will create a retain cycle!
///         (Use @strongify/@weakify dance to avoid this.)
///     - The returned BlockObserver  can be used to cancel the observation prematurely by calling `- cancelObservation` on it.
///     - If you observe a primitive value such as int or float, it will arrrive in the callback boxed in an NSValue. Use the unboxNSValue() macro to conveniently get the underlying primitive inside the callback.
- (BlockObserver *)observe:(NSString *)keyPath withBlock:(ObservationCallbackBlockWithNew)callbackBlock;

/// Basic observation with some extra options.
/// The default options are:
///     - receiveInitialValue = YES which means the callback will immediately fire upon creation with the current value of self.keyPath, instead of first firing on the first change of self.keyPath after you call this method.
///     - receiveOldAndNewValues = NO which means that, inside the callbackBlock, you only receive the updated value - not the previous values - of self.keyPath.
///         > Use ObservationCallbackBlockWithOldAndNew as the callbackBlock's type if you set this option to YES.
- (BlockObserver *)observe:(NSString *)keyPath receiveInitialValue:(BOOL)receiveInitialValue receiveOldAndNewValues:(BOOL)receiveOldAndNewValues withBlock:(ObservationCallbackBlock)callbackBlock;

@end

@interface BlockObserver (MFBlockObserverInterface)

/// Check state
- (BOOL)observationIsActive;

/// Cancel observation
- (void)cancelObservation;
+ (void)cancelObservations:(NSArray<BlockObserver *> *)observers;

/// Observe latest
///     Note this when using:
///     - Caution: If any of the observedObjects are retained inside the callbackBlock -> retain cycle!
///     - If one of the observed objects is deallocated during the observation, the latest value will appear as 'nil' in the subsequent callbacks triggered by any of the other objects updating, unless the value is retained elsewhere. (The observedObjects don't retain the latest values to help prevent reference cycles).
///     - The callbackBlock will be executed on the thread where the underlying value was changed, as soon as the value change happens. That means the callback might run on different threads concurrently. You can use `pthread`, `dispatch_async` `@synchronized()` or similar to handle concurrency inside the callback.
///     - The returned array of BlockObservers can be used to cancel observation prematurely using `[BlockObserver cancelObservations:arrayOfBlockObservers]`.

+ (NSArray<BlockObserver *> *)observeLatest2:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest2)callbackBlock;
+ (NSArray<BlockObserver *> *)observeLatest3:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest3)callbackBlock;
+ (NSArray<BlockObserver *> *)observeLatest4:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest4)callbackBlock;
+ (NSArray<BlockObserver *> *)observeLatest5:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest5)callbackBlock;
+ (NSArray<BlockObserver *> *)observeLatest6:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest6)callbackBlock;
+ (NSArray<BlockObserver *> *)observeLatest7:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest7)callbackBlock;
+ (NSArray<BlockObserver *> *)observeLatest8:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest8)callbackBlock;
+ (NSArray<BlockObserver *> *)observeLatest9:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest9)callbackBlock;

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
