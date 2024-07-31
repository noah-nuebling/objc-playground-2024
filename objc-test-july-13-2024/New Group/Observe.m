//
//  BlockObserver.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 30.07.24.
//

#import "Observe.h"
#import "objc/runtime.h"

///
/// I think we can replace any need for reactive frameworks in our app with a very simple custom API providing a thin wrapper around Apple's Key-Value-Observation.
///
/// Design considerations:
///
/// We want to create a very simple API consisting of 4 methods:
///
///    Simple observation:
///    ```
///    BlockObserver *observer = [button observe@"value" withBlock:^(NSString *newValue) {
///        newValue -= 1
///        self.something = value;
///    }];
///    ```
///
///    Cancel observation:
///    ```
///    [button removeBlockObserver:observer];
///    ```
///
///    Observe combined streams:
///    ```
///    NSArray *observers = [BlockObserver observeLatest:@[@[button, @"value"], @[slider, @"doubleValue"]] withBlock ^(NSArray *latestValues) {
///        int buttonValue = unboxNSValue(int, latestValues[0]);
///        double sliderValue = unboxNSValue(int, latestValues[1]);
///        ...
///    }];
///    ```
///
///     Cancel:
///    ```
///    [BlockObserver removeBlockObservers:observers];
///    ```
///
/// Comparison with Reactive frameworks:
///     - Key-value-observation should be extremely fast, since it's quite old and mature and at the core of many of Apple's libraries.
///         It should be much faster than ReactiveSwift, and perhaps even faster than Combine.
///     - Most reactive features like backpressure, errors, hot & cold signals etc, are totally unnecessary for us.
///     - Any 'maps' or 'filters' or similar transforms on 'streams of values over time' we can simply do inside our observation callback block.
///         E.g. filter is just an `if (xyz) return;` statement. compactMap is just `if (newValue == nil) return;`
///     - We can do scheduling by just calling functions like `dispatch_async()` inside the callback block.
///     - As far as I can think of, the only useful thing for MMF  in Reactive frameworks that goes beyond this basic API would be debouncing,
///             but even that we could replace by adding an NSTimer and 3 lines of code inside an observation callback block.
///     - Basically all property or other values assigned to any NSObject (even NSDictionary) should be observable with KVO - and by extension our BlockObserver API.
///         (KVO works on any setters that use the `setValue:` naming scheming afaik)
///
///     -> Overall this should provide a very performant, simple and modular interface for doing everything we want to do with a Reactive framework.
///
/// Also see:
///     - KVOBasics: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueObserving/Articles/KVOBasics.html
///     - Key Value Coding Programming Guide: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueCoding/index.html#//apple_ref/doc/uid/10000107-SW1
///
/// Performance:
///     Just ran benchmarks on kvo wrapper and this is 3.5x - 5.0x (Update: 4.5x - 6x after optimizations) faster than Combine!! And combine can already be around 2x as fast as ReactiveSwift and 1.5x as fast as RxSwift according to benchmarks I found on GitHub. So this should outperform the Reactive framework we're currently using by several factors, while offering an imo nicer interface, which is great!
///
///     However, I also tested against a 'primitive' implementation in swift and objc that replaces observation with manual invokations of the callback block whenever the underlying value changes, and the difference is staggering! The 'primitive' Swift implementation is 134x faster than our kvo wrapper for a simple example and 929x (!!) faster than our kvo wrapper for the 'combineLatest logic. (And combine is another factor 5x - 10x slower)
///
///     So overall, while this
///
///     The checksums all matched, so they computed the same thing and we built with optimizations.
///
///     ------------------
///     BlockObserver Bench:
///     ------------------
///     Running simple tests with 10000000 iterations...
///     Combine time: 45.459512
///     kvo time: 9.590202
///     primitive objc time: 0.302365
///     primitive swift time: 0.071346
///     swift is **4.23x** faster than objc. objc is **31.71x** faster than kvo. kvo is **4.74x** faster than Combine
///     Running combineLatest tests with 2500000 iterations....
///     Combine time: 54.844566
///     kvo time: 14.305337
///     primitive objc time: 0.059409
///     primitive swift time: 0.015361
///     swift is **3.86x** faster than objc. objc is **240.79x** faster than kvo. kvo is **3.83x** faster than Combine
///     Program ended with exit code: 0


#pragma mark - BlockObserver

@interface BlockObserver ()

- (NSObject *)latestValue;

@property (weak, nonatomic)     NSObject *weakObservedObject; /// Doesn't haveee to be weak I think bc we use `_globalBlockObservers` to prevent retain cycles. If we remove weak we could remove all the `strongObject = _weakObservedObject` unwrapping code;
@property (strong, nonatomic)   NSString *observedKeyPath;
@property (assign, nonatomic)   NSKeyValueObservingOptions observingOptions;
@property (strong, nonatomic)   id callbackBlock;
@property (assign, nonatomic)   BOOL observationIsStopped;

@end

@implementation BlockObserver


/// Define context
///     Kind of unncecessary. This is designed for when a superclass also observes the same keyPath on the same object.
static void *_BlockObserverContext = "mfBlockObserverContext";

///
/// Lifecycle
///

- (void)dealloc {
    [self stopObserving];
}

- (instancetype)initWithObject:(NSObject *)observedObject keyPath:(NSString *)keyPath receiveInitialValue:(BOOL)receiveInitialValue receiveOldAndNewValues:(BOOL)receiveBeforeAndAfterValues callback:(id)callback {
    
    /// Get self
    self = [super init];
    if (!self) return nil;
    
    /// Set up options
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew;
    options = options | (receiveBeforeAndAfterValues ? NSKeyValueObservingOptionOld : 0);
    options = options | (receiveInitialValue ? NSKeyValueObservingOptionInitial : 0);
    
    /// Store args
    _weakObservedObject = observedObject;
    _observedKeyPath = keyPath;
    _observingOptions = options;
    _callbackBlock = callback;
    
    /// Init other state
    _observationIsStopped = YES;
    
    /// Return self
    return self;
}

///
/// Handle callback
///

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    /// Guard context
    if (context != _BlockObserverContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    /// Get strong object reference
    ///     We don't need to do this since a strong ref to the object is already passed in as an argument. But I'm just learning this pattern so I'm doing it
    ///     Update: This stuff starts to matter for performance here. 
//    NSObject *strongObject = _weakObservedObject;
//    if (strongObject == nil) return;
    
    /// Parse options
    BOOL receivesOldAndNewValues = (_observingOptions & NSKeyValueObservingOptionNew)
                                    && (_observingOptions & NSKeyValueObservingOptionOld);
    /// Handle changed value
    NSObject *oldValue = nil;
    NSObject *newValue = change[NSKeyValueChangeNewKey];
    if (receivesOldAndNewValues) {
        oldValue = change[NSKeyValueChangeOldKey]; /// This stuff starts to matter for performance here I think.
    }
    
    /// Validate
    
#if DEBUG
    
    /// Validate options
    assert(_observingOptions & NSKeyValueObservingOptionNew);
    
    /// Handle change-kind
    NSKeyValueChange changeKind = [change[NSKeyValueChangeKindKey] unsignedIntegerValue];
    assert(changeKind == NSKeyValueChangeSetting); /// We just handle values being set directly - none of the array and set observation stuff.
    
    /// Handle indexes
    NSIndexSet *changedIndexes = change[NSKeyValueChangeIndexesKey];
    assert(changedIndexes == nil); /// We don't know how to handle the array and set observation stuff
    
    /// Handle prior values
    BOOL isPrior = [change[NSKeyValueChangeNotificationIsPriorKey] boolValue];
    assert(!isPrior); /// We don't handle prior-value-observation (getting a callback *before* the value changes)
    
    /// Validate changed value
    if (!receivesOldAndNewValues) {
        assert(oldValue == nil);
    }
    assert(newValue != nil);
    
#endif
    
    if (receivesOldAndNewValues) {
        ((ObservationCallbackBlockWithOldAndNew)_callbackBlock)(oldValue, newValue);
    } else {
        ((ObservationCallbackBlockWithNew)_callbackBlock)(newValue);
    }
}

///
/// Start & stop observation
///

- (void)startObserving { /// May not be thread safe when called by outsiders
    
    NSObject *strongObject = _weakObservedObject;
    if (strongObject == nil) return;
    
    if (!_observationIsStopped) return;
    _observationIsStopped = NO;
    
    [strongObject addObserver:self forKeyPath:_observedKeyPath options:_observingOptions context:_BlockObserverContext];
}

- (void)stopObserving { /// May not be thread safe when called by outsiders
    
    NSObject *strongObject = _weakObservedObject;
    if (strongObject == nil) return;
    
    if (_observationIsStopped) return;
    _observationIsStopped = YES;
    
    [strongObject removeObserver:self forKeyPath:_observedKeyPath context:_BlockObserverContext];
}

///
/// Convenience interface
///

- (NSObject *)latestValue {
    
    /// Making a cache for this might be a little faster but this is unused atm anyways. (Because we use NSPointerArray which is faster than this even if use an `__unsafe_unretained` cache in here.)
    
    NSObject *strongObject = _weakObservedObject;
    if (strongObject == nil) return nil;
    
    return [strongObject valueForKeyPath:_observedKeyPath];
}

@end

#pragma mark - Dealloc callback

/// Note: Should be thread-safe

@interface DeallocTracker : NSObject
@property (strong, nonatomic) void (^deallocCallback)(void);
@end

@implementation DeallocTracker

- (void)dealloc {
    _deallocCallback();
}

@end

static NSMutableArray *getDeallocTrackers(NSObject *object) {
        
    static const char *key = "mfDeallocTrackers";
    NSMutableArray *result = objc_getAssociatedObject(object, key);
    
    if (result != nil) {
        return result;
    }
    
    @synchronized (object) {
        /// Double-checked locking pattern, says Claude, makes sense when you think about it. Concurrency is hard.
        result = objc_getAssociatedObject(object, key);
        if (result == nil) {
            result = [NSMutableArray array];
            objc_setAssociatedObject(object, key, result, OBJC_ASSOCIATION_RETAIN);
        }
    }
    
    return result;
}

static void addDeallocTracker(NSObject *object, void (^deallocCallback)(void)) {
    
    /// Create tracker
    DeallocTracker *newTracker = [[DeallocTracker alloc] init];
    newTracker.deallocCallback = deallocCallback;
    
    /// Get trackers
    NSMutableArray *deallocTrackers = getDeallocTrackers(object);
    
    /// Add tracker
    ///     `newTracker` is retained by `object` after this step.
    ///
    /// Explanation:
    ///     When `object` is `dealloc`ed the
    ///     associated `deallocTrackers` array and all its contents are released.
    ///     Subsequently, `deallocTrackers` contents are then also all `dealloc`ed,
    ///     (If the contents are not retained anywhere else, which we shouldn't do)
    ///     which will cause the `deallocCallback` of our `newTracker` (as well as any other dealloc trackers) to fire.
    
    @synchronized (object) {
        [deallocTrackers addObject:newTracker];
    }

}

#pragma mark - NSObject category

/// Note: Should be thread-safe

///
/// Global storage
///

static NSMutableSet *getGlobalBlockObservers(void) {
    
    /// Store all blockObservers across the entire process
    
    static NSMutableSet *result = nil;
    
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{ /// This makes it thread-safe, and is faster than @synchronized
        result = [NSMutableSet set];
    });
    
    return result;
}

@implementation NSObject (MFBlockObserver)

///
/// Add observation
///

- (BlockObserver *)observe:(NSString *)keyPath withBlock:(ObservationCallbackBlockWithNew)block {
    
    /// Convenience interface
    
    BlockObserver *blockObserver = [self observe:keyPath receiveInitialValue:YES receiveOldAndNewValues:NO withBlock:block];
    [blockObserver startObserving];
    
    return blockObserver;
}

- (BlockObserver *)observe:(NSString *)keyPath receiveInitialValue:(BOOL)receiveInitialValue receiveOldAndNewValues:(BOOL)receiveOldAndNewValues withBlock:(ObservationCallbackBlock)callback {
    
    /// Create blockObserver
    ///     It automatically registers itself as an observer of self.
    BlockObserver *blockObserver = [[BlockObserver alloc] initWithObject:self keyPath:keyPath receiveInitialValue:receiveInitialValue receiveOldAndNewValues:receiveOldAndNewValues callback:callback];
    
    /// Validate
    assert(![getGlobalBlockObservers() containsObject:blockObserver]);
    
    /// Add blockObserver to global set
    ///     To retain it in the global set. We don't store the `blockObserver` on `self` directly to avoid retain cycles when the blockObserver retains self,
    ///     which can easily happen, e.g. when the blockObserver's callbackBlock captures `self`.
    @synchronized (self) {
        [getGlobalBlockObservers() addObject:blockObserver];
    }
    
    /// Add a dealloc callback to self
    ///     When self is dealloced, we remove the blockObserver from the global set which releases it.
    __block NSObject *__weak weakSelf = self;
    addDeallocTracker(self, ^{
        @synchronized (weakSelf) {
            [getGlobalBlockObservers() removeObject:blockObserver];
        }
    });

    /// Return blockObserver
    ///     The observer is primarily a handle to call `removeBlockObserver:` later.
    ///     We have to make sure nothing breaks if the caller is retaining or manipulating the returned blockObserver.
    ///         Alternatively, we could just cast to `void *` to avoid this but I don't like making things opaque.
    return blockObserver;
}

///
/// Remove observation
///

- (void)removeBlockObserver:(BlockObserver *)blockObserver {
    @synchronized (self) {
        [getGlobalBlockObservers() removeObject:blockObserver];   /// Normally, the block observer should be released after this, except if it is retained by an outsider.
        [blockObserver stopObserving];                            /// In case the blockObserver is not dealloced after being released we stop its observation manually.
    }
}

@end

#pragma mark - Combined Observation

@implementation BlockObserver (CombinedValueStreamObservation)

///
/// Add observers
///

+ (NSArray<BlockObserver *> *)observeLatestValuesForKeypaths:(NSArray<NSString *> *)keyPaths onObjects:(NSArray<NSObject *> *)objects withBlock:(ObservationCallbackBlockWithLatest)callback {
    
    /// Extract
    NSInteger n = objects.count;
    
    /// Validate
    assert(keyPaths.count == objects.count);
    assert(2 <= n && n <= 9);
    
    /// Declare result
    NSMutableArray<BlockObserver *> *observers = [NSMutableArray array];
    
    /// Create value cache
    NSPointerArray *latestValueCache = [NSPointerArray weakObjectsPointerArray];
    
    for (int i = 0; i < n; i++) {
        [latestValueCache addPointer:(__bridge void *)[objects[i] valueForKeyPath:keyPaths[i]]];
    }
    
    for (int i = 0; i < n; i++) {
        
        /// Only receive initialValue on one object
        ///     So we don't receive the same initial values n times.
        BOOL doReceiveInitialValue = i == 0;
        
        /// Create observer
        BlockObserver *blockObserver = [objects[i] observe:keyPaths[i] receiveInitialValue:doReceiveInitialValue receiveOldAndNewValues:NO withBlock:^(NSObject *newValue) {
            
            /// Note on thread safety:
            ///     We shouldn't have to synchronize the cache update, since every observer uses a different index in the cache array, so they don't actually share data. Not sure how NSPointerArray behaves though..
            ///     As for the callback calls,`[latestValueCache pointerAtIndex:]` will return valid strong pointer, or nil (since it's a weak pointer array), this should ensure reasonable thread safety I think.
                
            /// Update cache
            [latestValueCache replacePointerAtIndex:i withPointer:(__bridge void *)newValue];
            
            /// Call the callback
            if (n == 2) {
                ((ObservationCallbackBlockWithLatest2)callback)(i,
                                                                [latestValueCache pointerAtIndex:0],
                                                                [latestValueCache pointerAtIndex:1]);
            }
            else if (n == 3) {
                ((ObservationCallbackBlockWithLatest3)callback)(i,
                                                                [latestValueCache pointerAtIndex:0],
                                                                [latestValueCache pointerAtIndex:1],
                                                                [latestValueCache pointerAtIndex:2]);
            }
            else if (n == 4) {
                ((ObservationCallbackBlockWithLatest4)callback)(i,
                                                                [latestValueCache pointerAtIndex:0],
                                                                [latestValueCache pointerAtIndex:1],
                                                                [latestValueCache pointerAtIndex:2],
                                                                [latestValueCache pointerAtIndex:3]);
            }
            else if (n == 5) {
                ((ObservationCallbackBlockWithLatest5)callback)(i,
                                                                [latestValueCache pointerAtIndex:0],
                                                                [latestValueCache pointerAtIndex:1],
                                                                [latestValueCache pointerAtIndex:2],
                                                                [latestValueCache pointerAtIndex:3],
                                                                [latestValueCache pointerAtIndex:4]);
            }
            else if (n == 6) {
                ((ObservationCallbackBlockWithLatest6)callback)(i,
                                                                [latestValueCache pointerAtIndex:0],
                                                                [latestValueCache pointerAtIndex:1],
                                                                [latestValueCache pointerAtIndex:2],
                                                                [latestValueCache pointerAtIndex:3],
                                                                [latestValueCache pointerAtIndex:4],
                                                                [latestValueCache pointerAtIndex:5]);
            }
            else if (n == 7) {
                ((ObservationCallbackBlockWithLatest7)callback)(i,
                                                                [latestValueCache pointerAtIndex:0],
                                                                [latestValueCache pointerAtIndex:1],
                                                                [latestValueCache pointerAtIndex:2],
                                                                [latestValueCache pointerAtIndex:3],
                                                                [latestValueCache pointerAtIndex:4],
                                                                [latestValueCache pointerAtIndex:5],
                                                                [latestValueCache pointerAtIndex:6]);
            }
            else if (n == 8) {
                ((ObservationCallbackBlockWithLatest8)callback)(i,
                                                                [latestValueCache pointerAtIndex:0],
                                                                [latestValueCache pointerAtIndex:1],
                                                                [latestValueCache pointerAtIndex:2],
                                                                [latestValueCache pointerAtIndex:3],
                                                                [latestValueCache pointerAtIndex:4],
                                                                [latestValueCache pointerAtIndex:5],
                                                                [latestValueCache pointerAtIndex:6],
                                                                [latestValueCache pointerAtIndex:7]);
            }
            else if (n == 9) {
                ((ObservationCallbackBlockWithLatest9)callback)(i,
                                                                [latestValueCache pointerAtIndex:0],
                                                                [latestValueCache pointerAtIndex:1],
                                                                [latestValueCache pointerAtIndex:2],
                                                                [latestValueCache pointerAtIndex:3],
                                                                [latestValueCache pointerAtIndex:4],
                                                                [latestValueCache pointerAtIndex:5],
                                                                [latestValueCache pointerAtIndex:6],
                                                                [latestValueCache pointerAtIndex:7],
                                                                [latestValueCache pointerAtIndex:8]);
            } else {
                assert(false);
            }
        }];
        
        /// Store observer
        [observers addObject:blockObserver];
        
        /// Start observing
        [blockObserver startObserving];
    }
    
    /// Return
    return observers;
}

///
/// Remove observers
///

+ (void)removeBlockObservers:(NSArray<BlockObserver *> *)observers {
    
    for (BlockObserver *observer in observers) {
        
        id strongObject = observer.weakObservedObject; /// This should make it thread safe I think.
        if (strongObject == nil) continue;
        
        [strongObject removeBlockObserver:observer];
    }
}

///
/// Add Observers - convenience
///

+ (NSArray<BlockObserver *> *)observeLatest2:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest2)callback {
    return [self observeLatest:objectsAndKeyPaths withBlock:(id)callback];
}

+ (NSArray<BlockObserver *> *)observeLatest3:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest3)callback {
    return [self observeLatest:objectsAndKeyPaths withBlock:(id)callback];
}

+ (NSArray<BlockObserver *> *)observeLatest4:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest4)callback {
    return [self observeLatest:objectsAndKeyPaths withBlock:(id)callback];
}
+ (NSArray<BlockObserver *> *)observeLatest5:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest5)callback {
    return [self observeLatest:objectsAndKeyPaths withBlock:(id)callback];
}
+ (NSArray<BlockObserver *> *)observeLatest6:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest6)callback {
    return [self observeLatest:objectsAndKeyPaths withBlock:(id)callback];
}
+ (NSArray<BlockObserver *> *)observeLatest7:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest7)callback {
    return [self observeLatest:objectsAndKeyPaths withBlock:(id)callback];
}
+ (NSArray<BlockObserver *> *)observeLatest8:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest8)callback {
    return [self observeLatest:objectsAndKeyPaths withBlock:(id)callback];
}
+ (NSArray<BlockObserver *> *)observeLatest9:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest9)callback {
    return [self observeLatest:objectsAndKeyPaths withBlock:(id)callback];
}

+ (NSArray<BlockObserver *> *)observeLatest:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest)callback {
    
    ///
    ///  You can invoke this with an array of object-keyPath pairs like this:
    ///
    ///    ```
    ///    NSArray *observers = [BlockObserver observeLatest:@[@[button, @"value"], @[slider, @"doubleValue"]] withBlock ^(NSArray *latestValues) {
    ///        int buttonValue = unboxNSValue(int, latestValues[0]);
    ///        double sliderValue = unboxNSValue(int, latestValues[1]);
    ///        ...
    ///    }];
    ///    ```
    
    /// Parse input
    
    NSMutableArray *objects = [NSMutableArray array];
    NSMutableArray *keyPaths = [NSMutableArray array];

    for (NSArray *objectAndKeyPath in objectsAndKeyPaths) {
        
        assert(objectAndKeyPath.count == 2);
        assert([objectAndKeyPath[1] isKindOfClass:[NSString class]]); /// KeyPaths need to be strings
        
        [objects addObject:objectAndKeyPath[0]];
        [keyPaths addObject:objectAndKeyPath[1]];
    }
    
    /// Call core
    return [self observeLatestValuesForKeypaths:keyPaths onObjects:objects withBlock:callback];
}

@end
