//
//  BlockObserver.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 30.07.24.
//

#import "Observe.h"
#import "objc/runtime.h"

///
/// Conclusion: Should you use this?
///     - This adds very light "reactive style" convenience interface on top of kvo.
///     - It's available in objc which I like writing more.
///     - It's usually slightly faster than combine but in the same ballpark.  For performance critical things, you'd still want to use simple function calls and for UI stuff the performance difference doesn't matter.
///     - I wrote it and control it so I might understand how to use it better.
///         - Actually, when using Combine as a wrapper for kvo, using `someObject.publisher(for:<keyPath>)`, then Combine is around 4x slower in our tests, but for UI Stuff this still probably doesn't matter.
///     - I have a general dislike for Swift and all this weird fancy abstractions that don't add much and make the language feel inelegant imo. (`CompactMapping a subscription` in combine is the same as using `if (newValue == nil) return;` in our interface.) But this doesn't really matter for the quality of the app, it's just my personal preference.
///     - The build times for MMF 3 are really annoyingly slow. And I suspect that swift is a big factor in that. Since I also sort of dislike writing Swift, I might want to move away from Swift and write more of the UI Stuff in objc. And this might enable that. Some of the main reasons we use so much swift is that we wanted to use reactive patterns for the UI of MMF, which lead us to include the ReactiveSwift framework and build much of the UI code in Swift.
///     - BIG CON: This needs to be thread safe. I tried but thread safety is hard. If there are subtle bugs in this, we might make the app less stable vs using an established framework or API.
///     -> Overall this was a cool experiment. It was fund and I learned a bunch of things. Maybe we can adopt this into MMF at some point, but we should probably only adopt it for a new major release where we can thoroughly test this before rolling it out to non-beta users.
///
///     Other takeaways:
///     - Due to the Benchmarks we made for this I saw that, for simple arithmetic and function calling, pure swift seems to be around 4 - 6x faster than our pure C code!! That's incredible and very unexpected.
///         Unfortunately, when you use frameworks or higher level datatypes with Swift, and interoperate with objc, that can sometimes slow things down a lot in unpredictable ways. (See the whole `SWIFT_UNBRIDGED` hassle in MMF.) Objc/C and its frameworks seem more predictable and consistent to me. But for really low level routines or if you use it right, swift can actually be incredibly fast, which is cool and good to know, and makes me like the language a bit more.
///
///
/// Main discussion
///     I think we can replace any need for reactive frameworks in our app with a very simple custom API providing a thin wrapper around Apple's Key-Value-Observation.
///
///     Design considerations:
///
///     We want to create a very simple API consisting of 4 methods:
///
///        Simple observation:
///             ```
///             BlockObserver *buttonObserver = [button observe@"value" withBlock:^(NSString *newValue) {
///                 otherValue = [newValue stringByAppendingString:@"Hello from KVO block!"]
///                 self.something = value;
///             }];
///             ```
///
///        Cancel observation:
///             ```
///             [buttonObserver cancelObservation];
///             ```
///
///        Observe latest:
///             ```
///             NSArray *observers = [BlockObserver observeLatest2:@[@[button, @"value"], @[slider, @"doubleValue"]] withBlock ^(int updatedValueIndex, NSValue *v1, NSValue *v2) {
///                 int buttonValue = unboxNSValue(int, v1);
///                 double sliderValue = unboxNSValue(int, v2);
///                 ...
///             }];
///             ```
///
///         Cancel observeLatest:
///             ```
///             [BlockObserver cancelObservations:observers];
///             ```
///
/// Comparison with Reactive frameworks:
///     - Key-value-observation should be extremely fast, since it's quite old and mature and at the core of many of Apple's libraries.
///         It should be much faster than ReactiveSwift, and perhaps even faster than Combine. Update: Combine also seems to use KVO under the hood at least when observing properties @objc objects, but it adds a lot of overhead
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
///
///     Caveat:
///         - These bad Combine results were for using the `someObject.publisher(for:)` API inside  which is actually a wrapper for KVO. When using the more swift-native `@Published` macro, Combine is almost as fast as our implementation:
///         -> Based on one test, ours is only  1.14x faster than Combine for the basic observation and 1.08x faster for the combineLatest observation when using `@Published` in Combine.
///

///
/// Technical details:
///     On use of `@synchronized`:
///         We use `@synchronized(observedObject)` throughout this implementation to ensure thread-safety.
///         Afaik `@synchronized(observedObject)`uses a recursiveLock under-the-hood, so there shouldn't be deadlocks even if some other code also tries to synchronize on the `observedObject`.

#pragma mark - BlockObserver

@interface BlockObserver ()

/// Constants
/// Notes:
/// - Retain cycles will occur if `callbackBlock` captures the observed object. This clients need to use weak/strong dance to avoid. (Use @weakify and @strongify)
/// - weakObservedObject being weak actually makes this noticable slower since we always need to unwrap it and check for nil

@property (unsafe_unretained, nonatomic, readonly)  NSObject *unsafeObservedObject;
@property (weak, nonatomic, readonly)               NSObject *weakObservedObject;
@property (strong, nonatomic, readonly)             NSString *observedKeyPath;
@property (assign, nonatomic, readonly)             NSKeyValueObservingOptions observingOptions;
@property (strong, nonatomic, readonly)             id callbackBlock;

/// Method

- (NSObject *)latestValue;


@end

@implementation BlockObserver  {
    /// State
    @public BOOL _observationHasBeenAdded;  /// This state mostly exists to validate that we're producing unbalanced calls to the add/remove methods.
    @public BOOL _observationHasBeenRemoved;
    @public __weak NSObject *_weakObservedObject;   /// Making the ivars public bc I just learned that that's possible
}


/// Define context
///     Kind of unncecessary. This is designed for when a superclass also observes the same keyPath on the same object.
static void *_BlockObserverContext = "mfBlockObserverContext";

///
/// Lifecycle
///

- (instancetype)initWithObject:(NSObject *)observedObject keyPath:(NSString *)keyPath receiveInitialValue:(BOOL)receiveInitialValue receiveOldAndNewValues:(BOOL)receiveBeforeAndAfterValues callback:(id)callback {
    
    /// Thread safe
    ///     Since it doesn't interact with any shared mutable state
    ///     (our ivars aren't shared state yet, since nobody else has a reference to us, as we're just being created.)
    
    /// Get self
    self = [super init];
    if (!self) return nil;
    
    /// Set up options
    NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew;
    options = options | (receiveBeforeAndAfterValues ? NSKeyValueObservingOptionOld : 0);
    options = options | (receiveInitialValue ? NSKeyValueObservingOptionInitial : 0);
    
    /// Store args
    _weakObservedObject = observedObject;
    _unsafeObservedObject = observedObject;
    _observedKeyPath = keyPath;
    _observingOptions = options;
    _callbackBlock = callback;
    
    /// Init other state
    _observationHasBeenAdded = NO;
    _observationHasBeenRemoved = NO;
    
    /// Return self
    return self;
}

///
/// Handle callback
///

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
    
    /// Thread safe
    ///     As we're not interacting with any shared mutable state.
    
    /// Guard context
    if (context != _BlockObserverContext) {
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    /// Parse options
    BOOL receivesOldAndNewValues = (_observingOptions & NSKeyValueObservingOptionNew)
                                    && (_observingOptions & NSKeyValueObservingOptionOld);
    /// Handle changed value
    NSObject *newValue = change[NSKeyValueChangeNewKey];
    NSObject *oldValue = receivesOldAndNewValues ? change[NSKeyValueChangeOldKey] : nil;
    
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
    
    /// Send callback.
    if (receivesOldAndNewValues) {
        ((ObservationCallbackBlockWithOldAndNew)_callbackBlock)(oldValue, newValue);
    } else {
        ((ObservationCallbackBlockWithNew)_callbackBlock)(newValue);
    }
}

///
/// Start & stop observation
///

- (void)addObservation {
    
    /// Not thread safe
    ///     Needs to be balanced with removeObservation calls.
    
    /// Guard unbalanced calls
    if (_observationHasBeenRemoved) { assert(false); return; }
    if (_observationHasBeenAdded) { assert(false); return; }
    _observationHasBeenAdded = YES;
    
    /// Unwrap weak ref
    if (_weakObservedObject == nil) { assert(false); return; }
    
    /// Add observer
    [_weakObservedObject addObserver:self forKeyPath:_observedKeyPath options:_observingOptions context:_BlockObserverContext];
}

- (void)removeObservation {
    
    /// Not thread safe.
    ///     Needs to be balanced with addObservation calls

    /// Guard unbalanced calls
    if (!_observationHasBeenAdded) { assert(false); return; }
    if (_observationHasBeenRemoved) { assert(false); return; }
    _observationHasBeenRemoved = YES;
    
    /// Unwrap weak ref
    if (_weakObservedObject == nil) { assert(false); return; }
    
    /// Remove observer
    [_weakObservedObject removeObserver:self forKeyPath:_observedKeyPath context:_BlockObserverContext];
}

- (void)removeObservation_UnsafeObservee {
    
    /// - Not thread safe
    /// - Calling this after the observedObject is has been freed from memory is an error
    /// - Why do we need this?
    ///     -> From my observations, during dealloc, the observedObject is in an intermediate state: Weak pointers to it will already have been nil'ed but the object will not yet have been freed from memory and calling `removeObserver:` on it seems to not cause memory corruption errors.
    ///     -> I assume that the observation has to be removed before the observed object is freed from memory based on this pretty flaky evidence: https://stackoverflow.com/questions/21639675/best-practice-to-remove-an-object-as-observer-for-some-kvo-property
    ///         - I have not actually seen errors when failing to call `removeObserver:` before the observedObject is removed from memory *or* when calling `removeObserver:` on the object while its deallocing. Both seem dangerous but work ok so far. Not sure what's better.
    ///
    /// Update: Since the evidence that we need to do this at all is so flaky (Just a single 10 year-old SO post regarding an error seen on iOS) and since calling a method on a deallocatting object might lead to other issues, we're just going return here.
    ///     -> Probably should remove the `_unsafeObservedObject` which we added for this.
    ///
    /// Just found SO answer by Rob Mayoff which explains things: https://stackoverflow.com/a/18065286/10601702
    ///     -> It seems you don't have to stopObserving when the observedObject  is dealloc'ed under macOS 11 Big Sur and later.
    ///
    
    return;
    
    /// Guard unbalanced calls
    if (!_observationHasBeenAdded) { assert(false); return; }
    if (_observationHasBeenRemoved) { assert(false); return; }
    _observationHasBeenRemoved = YES;
    
    /// Remove observer
    [_unsafeObservedObject removeObserver:self forKeyPath:_observedKeyPath context:_BlockObserverContext];
}

- (void)dealloc {
    
    /// Thread safe
    
    /// Stop observing on dealloc
    ///     As far as I understand, we need to stop the observation before either the BlockObserver or its observedObject are removed from memory.
    ///         Src for "needs to stop before observedObject is nil'ed" https://stackoverflow.com/questions/21639675/best-practice-to-remove-an-object-as-observer-for-some-kvo-property
    ///             -> Note: This has been changed in Big Sur and later
    ///         Src for "needs to stop before observer is nil'ed": "Removing an Object as an Observer" on https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueObserving/Articles/KVOBasics.html
    ///     How can we ensure this?
    ///         - In the most simple/ideal case, we'd want to call stopObservation() in the BlockObserver's and the observedObject's dealloc methods. However, we cannot insert code into the observedObject's dealloc method.
    ///         - We created the `deallocTracker` which lets us execute code whenever the observedObject is deallocated!  I am not sure of the order of deallocation and removal from memory between the deallocTracker and the
    ///             BlockObserver, but if we simply stop observation in whatever is dealloced first, we should be fine.
    ///         - Alternatively we could stop observation inside the BlockObservers dealloc and then make sure that the observedObject never is dealloced without the BlockObserver also being dealloc'ed. We could do that by inverting the ownership
    ///             so that the BlockObserver retains the observedObject instead of the other way around, but then we'd manually have to retain and manage the lifetimes of the blockObservers some other way which would be inconvenient. (The client would have
    ///             to keep a reference to the observer I think) We could also just make sure that each BlockObserver is only ever retained by its observedObject and nothing else, then it would always be dealloc'ed as soon as the observedObject is dealloc'ed, however
    ///             then we would have to keep the BlockObservers completely hidden from any clients to prevent additonal retains, which would complicate things since we currently
    ///             use the BlockObservers as handles to let the client stop observations. So I don't think these alternative approaches are as good.
    
    NSObject *strongObject = _weakObservedObject;
    if (strongObject == nil) return; /// Observed object was already dealloc'ed and its deallocTracker has called `stopObserving` already.
    
    @synchronized (strongObject) {
        [self removeObservation];
    }
}

///
/// Convenience interface
///

- (NSObject *)latestValue {
    
    /// This is unused.
    ///     (Because we use NSPointerArray for caching the latest value outside of here, which is faster than this even if we use an `__unsafe_unretained` cache in here.)
    
    NSObject *strongObject = _weakObservedObject;
    if (strongObject == nil) return nil;
    
    return [strongObject valueForKeyPath:_observedKeyPath];
}

@end

#pragma mark - Dealloc Tracker

/// Note: Should be thread-safe

@interface DeallocTracker : NSObject
@property (strong, nonatomic) void (^deallocCallback)(__unsafe_unretained NSObject *deallocatingObject);
@property (unsafe_unretained, nonatomic) NSObject *trackedObject; /// Use `unsafe_unretained`. weak ptr would be nil in the deallocCallback, and strong would cause memory leak. If anyone else than the trackedObject retains the dealloc tracker, it won't work anymore.
@end

@implementation DeallocTracker

- (void)dealloc {
    _deallocCallback(_trackedObject); /// Afaik, the `_trackedObject`will be in the process of dealloc'ing when the callback is invoked. Using some of its methods or properties would probably lead to errors!
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
            objc_setAssociatedObject(object, key, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC);
        }
    }
    
    return result;
}

static void addDeallocTracker(NSObject *object, void (^deallocCallback)(NSObject *deallocatingObject)) {
    
    /// Note:
    ///     If the deallocCallback retains `object` that's a retain cycle
    
    /// Create tracker
    DeallocTracker *newTracker = [[DeallocTracker alloc] init];
    newTracker.deallocCallback = deallocCallback;
    newTracker.trackedObject = object;
    
    /// Get trackers
    NSMutableArray *deallocTrackers = getDeallocTrackers(object);
    
    /// Add tracker
    ///     `newTracker` is retained by `object` after this step.
    ///
    /// Explanation:
    ///     When `object` is `dealloc`ed the
    ///     associated `deallocTrackers` array and all its contents are released.
    ///     Subsequently, `deallocTrackers` contents are then also all `dealloc`ed,
    ///     (as long as the contents are not retained anywhere else, which would be an error)
    ///     this will cause the `deallocCallback` of our `newTracker` (as well as all other dealloc trackers in the array) to fire.
    
    @synchronized (object) {
        [deallocTrackers addObject:newTracker];
    }

}


#pragma mark - Add & remove observers

/// Should be thread safe
///     and therefore all the interface functions should also be threadsafe since they are just wrappers around this.

static BOOL isBlockObserverActive(BlockObserver *observer) {
    /// Should be thread safe. I guess the three different base values could change while we're retrieving them, but that shouldn't lead to any invalid results, so it's ok.
    return observer->_observationHasBeenAdded && !observer->_observationHasBeenRemoved && (observer->_weakObservedObject != nil);
}

static NSMutableSet *getBlockObserversForObject(NSObject *observableObject) {
    
    /// Not thread safe
    ///     -> Only call when synced on `observableObject`
    /// Retrieve the block observers observing an object.
    
    static const char *key = "mfBlockObservers";
    
    NSMutableSet *result = objc_getAssociatedObject(observableObject, key);
    if (result != nil) {
        return result;
    } else {
        result = [NSMutableSet set];
        objc_setAssociatedObject(observableObject, key, result, OBJC_ASSOCIATION_RETAIN_NONATOMIC); /// Nonatomic since we're already synchronizing.
    }
    
    return result;
}

static BlockObserver *addBlockObserver(NSObject *observableObject, NSString *keyPath, BOOL receiveInitialValue, BOOL receiveOldAndNewValues, ObservationCallbackBlock callback) {
    
    /// Thread safe
    
    @synchronized (observableObject) {
        
        /// Create blockObserver
        BlockObserver *blockObserver = [[BlockObserver alloc] initWithObject:observableObject keyPath:keyPath receiveInitialValue:receiveInitialValue receiveOldAndNewValues:receiveOldAndNewValues callback:callback];
        
        /// Validate
        assert(![getBlockObserversForObject(observableObject) containsObject:blockObserver]);
        
        /// Add blockObserver to object
        ///     Now it is retained and the client won't have to retain it for the observation to stay active.
        
        [getBlockObserversForObject(observableObject) addObject:blockObserver];
        
        /// Add dealloc tracker
        ///     This callback gets called when observableObject is dealloc'ed
        
        if ((NO)) { /// Turning this off as it might not be necessary and I'm not sure syncing on the deallocating object could crash or anything. (Although I don't think so) See notes in`stopObserving_UnsafeObservee`. If this is really not necessary we could remove the `addDeallocTracker`.
            
            __weak BlockObserver *weakBlockObserver = blockObserver;
            addDeallocTracker(observableObject, ^(__unsafe_unretained NSObject *deallocatingObject) {
                
                @synchronized (deallocatingObject) { /// If we don't sync here it doesn't crash. Not sure why. This `__unsafe_unretained` stuff is bad
                    
                    /// Unwrap blockObserver
                    BlockObserver *strongBlockObserver = weakBlockObserver;
                    if (strongBlockObserver == nil) {
                        return; /// If the blockObserver is already nil, it should already have called -[stopObserving] in its dealloc method, so we can just return.
                    }
                    
                    /// Stop observation
                    [strongBlockObserver removeObservation_UnsafeObservee];
                }
            });
        }
        
        /// Start the blockObserver
        [blockObserver addObservation];
        
        /// Return blockObserver
        ///     Primarily intended as a handle to let the client cancel the observation
        return blockObserver;
    }
}

static void cancelBlockObservation(BlockObserver *blockObserver) {
    
    /// Thread safe
    
    /// Get & unwrap observedObject
    NSObject *strongObservedObject = blockObserver.weakObservedObject;
    if (strongObservedObject == nil) {
        return; /// If the observedObject is already nil it will already have stopped the observation and released the blockObserver already.
    }
    
    @synchronized (strongObservedObject) {
        
        /// Stop observation
        ///     In case the blockObserver is not dealloced after being released we stop its observation manually.
        [blockObserver removeObservation];
        
        /// Release the blockObserver
        ///     It should then normally be dealloced, unless its retained by an outsider.
        [getBlockObserversForObject(strongObservedObject) removeObject:blockObserver];
    }
}

static void cancelBlockObservations(NSArray<BlockObserver *> *blockObservers) {

    for (BlockObserver *observer in blockObservers) {
        cancelBlockObservation(observer);
    }
}

static NSArray<BlockObserver *> *addBlockObserversForLatestValues(NSArray<NSObject *> *objects, NSArray<NSString *> *keyPaths, ObservationCallbackBlockWithLatest callbackBlock) {
    
    /// Should be thread safe:
    ///     addBlockObserver() is thread safe, and inside the callback for each blockObserver we @synchronize.
    
    /// Extract
    NSInteger n = objects.count;
    
    /// Validate
    assert(keyPaths.count == objects.count);
    assert(2 <= n && n <= 9);
    n = MIN(n, 9);
    
    /// Declare result
    NSMutableArray<BlockObserver *> *observers = [NSMutableArray array];
    
    /// Create & fill cache
    NSPointerArray *latestValueCache = [NSPointerArray weakObjectsPointerArray];
    for (int i = 0; i < n; i++) {
        BOOL doReceiveInitialValue = i == 0;
        if (doReceiveInitialValue) {
            [latestValueCache addPointer:nil]; /// Optimization: (very irrelevant) since we receive a callback for the inital value of the i==0 object, we don't need to manually init the cache for it.
        } else {
            [latestValueCache addPointer:(__bridge void *)[objects[i] valueForKeyPath:keyPaths[i]]];
        }
    }
    
    for (int i = 0; i < n; i++) {
        
        /// Iterate objects
        
        /// Only receive initialValue on one object
        ///     So the `callbackBlock` doesn't receive the same initial values n times.
        BOOL doReceiveInitialValue = i == 0;
        BOOL receiveOldAndNewValues = NO;
        
        /// Create observer
        BlockObserver *blockObserver = addBlockObserver(objects[i], keyPaths[i], doReceiveInitialValue, receiveOldAndNewValues, ^(NSObject *newValue) {
            
            /// Note on retain cycles:
            ///     This block will be retained by each object in `objects[i]`, if we retain any of those objects in this block or in the inner callback block `callbackBlock` then we create a retain cycle!
            
            /// Note on weak pointers:
            ///     When we pass the weak pointers into the callbacks as arguments using `[latestValueCache pointerAtIndex:xyz]`, a copy of the pointer will be created for the callback's scope. (Since primitive values are always copied before being passed as args).  From my understanding copied pointer will be strong or nil (since all object-pointers are strong by default under ARC), and the value from the cache will never become nil during the callbackBlock's execution.
            
            /// Note on thread safety:
            ///     This callback will be invoked on the thread that updated the `newValue`. Locking everything here slows things down a bit, but we want to ensure that the `callbackBlock` isn't invoked multiple times at once. We could also let the caller pass in a dispatch queue or thread to execute the callbacks on. Might bring some minor performance gains.
            
            @synchronized (latestValueCache) {
                
                /// Update cache
                [latestValueCache replacePointerAtIndex:i withPointer:(__bridge void *)newValue];
                
                /// Call the callback
                if (n == 2) {
                    ((ObservationCallbackBlockWithLatest2)callbackBlock)(i,
                                                                         [latestValueCache pointerAtIndex:0],
                                                                         [latestValueCache pointerAtIndex:1]);
                }
                else if (n == 3) {
                    ((ObservationCallbackBlockWithLatest3)callbackBlock)(i,
                                                                         [latestValueCache pointerAtIndex:0],
                                                                         [latestValueCache pointerAtIndex:1],
                                                                         [latestValueCache pointerAtIndex:2]);
                }
                else if (n == 4) {
                    ((ObservationCallbackBlockWithLatest4)callbackBlock)(i,
                                                                         [latestValueCache pointerAtIndex:0],
                                                                         [latestValueCache pointerAtIndex:1],
                                                                         [latestValueCache pointerAtIndex:2],
                                                                         [latestValueCache pointerAtIndex:3]);
                }
                else if (n == 5) {
                    ((ObservationCallbackBlockWithLatest5)callbackBlock)(i,
                                                                         [latestValueCache pointerAtIndex:0],
                                                                         [latestValueCache pointerAtIndex:1],
                                                                         [latestValueCache pointerAtIndex:2],
                                                                         [latestValueCache pointerAtIndex:3],
                                                                         [latestValueCache pointerAtIndex:4]);
                }
                else if (n == 6) {
                    ((ObservationCallbackBlockWithLatest6)callbackBlock)(i,
                                                                         [latestValueCache pointerAtIndex:0],
                                                                         [latestValueCache pointerAtIndex:1],
                                                                         [latestValueCache pointerAtIndex:2],
                                                                         [latestValueCache pointerAtIndex:3],
                                                                         [latestValueCache pointerAtIndex:4],
                                                                         [latestValueCache pointerAtIndex:5]);
                }
                else if (n == 7) {
                    ((ObservationCallbackBlockWithLatest7)callbackBlock)(i,
                                                                         [latestValueCache pointerAtIndex:0],
                                                                         [latestValueCache pointerAtIndex:1],
                                                                         [latestValueCache pointerAtIndex:2],
                                                                         [latestValueCache pointerAtIndex:3],
                                                                         [latestValueCache pointerAtIndex:4],
                                                                         [latestValueCache pointerAtIndex:5],
                                                                         [latestValueCache pointerAtIndex:6]);
                }
                else if (n == 8) {
                    ((ObservationCallbackBlockWithLatest8)callbackBlock)(i,
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
                    ((ObservationCallbackBlockWithLatest9)callbackBlock)(i,
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
            }
        });
        
        /// Store the new observer
        [observers addObject:blockObserver];
    }
    
    /// Return
    return observers;
}

#pragma mark - Interface

/// This is a pure wrapper around the `Add & remove observers` C functions defined above.
///     Since that is thread safe, this should also be thread safe.

@implementation NSObject (MFBlockObservationInterface)

- (BlockObserver *)observeUpdates:(NSString *)keyPath withBlock:(ObservationCallbackBlockWithNew)block {
    return [self observe:keyPath receiveInitialValue:NO withBlock:block];
}

- (BlockObserver *)observe:(NSString *)keyPath withBlock:(ObservationCallbackBlockWithNew)block {
    return [self observe:keyPath receiveInitialValue:YES withBlock:block];
}

- (BlockObserver *)observe:(NSString *)keyPath receiveInitialValue:(BOOL)receiveInitialValue withBlock:(ObservationCallbackBlockWithNew)block {
    /// Start basic observation
    BOOL receiveOldAndNewValues = NO;
    BlockObserver *blockObserver = addBlockObserver(self, keyPath, receiveInitialValue, receiveOldAndNewValues, block);
    return blockObserver;
}

@end

@implementation BlockObserver (MFBlockObservationInterface)

- (BOOL)isActive {
    return isBlockObserverActive(self);
}

- (void)cancelObservation {
    cancelBlockObservation(self);
}
+ (void)cancelBlockObservations:(NSArray<BlockObserver *> *)observers {
    cancelBlockObservations(observers);
}

+ (NSArray<BlockObserver *> *)observeLatest:(NSArray<NSArray *> *)objectsAndKeyPaths withBlock:(ObservationCallbackBlockWithLatest)callback {
    
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
    return addBlockObserversForLatestValues(objects, keyPaths, callback);
}

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

@end
