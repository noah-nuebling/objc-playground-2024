//
//  BlockObserver.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 30.07.24.
//

#import "BlockObserver.h"
#import "objc/runtime.h"
#import "CoolMacros.h"
#import "EXTScope.h"
#import "objc/objc-sync.h"


/// I think we can replace any need for reactive frameworks in our app with a very simple custom API providing a thin wrapper around Apple's Key-Value-Observation.
/// 
/// Comparison with Reactive frameworks:
///     - Key-value-observation should be extremely fast, since it's quite old and mature and at the core of many of Apple's libraries.
///         It should be much faster than ReactiveSwift, and perhaps even faster than Combine. Update: Combine also seems to use KVO under the hood at least when observing properties @objc objects, but it adds a lot of overhead.
///     - Most reactive features like backpressure, errors, hot & cold signals etc, are totally unnecessary for us.
///     - Any 'maps' or 'filters' or similar transforms on 'streams of values over time' we can simply do inside our observation callback block.
///         E.g. filter is just an `if (xyz) return;` statement. compactMap is just `if (newValue == nil) return;`
///     - We can do scheduling by just calling functions like `dispatch_async()` inside the callback block.
///     - As far as I can think of, the only useful thing for MMF  in Reactive frameworks that goes beyond this basic API would be debouncing,
///             but even that we could replace by adding an NSTimer and 3 lines of code inside an observation callback block.
///     - Basically all properties or other values assigned to any NSObject (even NSDictionary) should be observable with KVO - and by extension our BlockObserver API.
///         (KVO works on any setters that use the `setValue:` naming scheming afaik) (Update: with our KVOMutationSupport.m code it even works for mutations on types like NSMutableString!)
///
///     -> Overall this should provide a very performant, simple and modular interface for doing everything we want to do with a Reactive framework.
///
/// Also see:
///     - KVOBasics: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueObserving/Articles/KVOBasics.html
///     - Key Value Coding Programming Guide: https://developer.apple.com/library/archive/documentation/Cocoa/Conceptual/KeyValueCoding/index.html#//apple_ref/doc/uid/10000107-SW1
///
/// Benchmarks:
///     Just ran benchmarks on kvo wrapper and this is 3.5x - 5.0x (Update: 4.5x - 6x after optimizations) faster than Combine!! And combine can already be around 2x as fast as ReactiveSwift and 1.5x as fast as RxSwift according to benchmarks I found on GitHub. So this should outperform the Reactive framework we're currently using by several factors, while offering an imo nicer interface, which is great!
///
///     However, I also tested against a 'primitive' implementation in swift and objc that replaces observation with manual invokations of the callback block whenever the underlying value changes, and the difference is staggering! The 'primitive' Swift implementation is 134x faster than our kvo wrapper for a simple example and 929x (!!) faster than our kvo wrapper for the 'combineLatest' logic. (And combine is another factor 5x - 10x slower)
///
///     The checksums all matched, so they computed the same thing and we built with optimizations.
///
///     Here's one of test run outputs:
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
///         - These bad Combine results were for using the `someObject.publisher(for:<keyPath>)` API which is actually a wrapper for KVO. When using the more swift-native `@Published` macro, Combine is almost as fast as our implementation:
///         -> Based on one test, ours is only  1.14x faster than Combine for the basic observation and 1.08x faster for the combineLatest observation when using `@Published` in Combine.
///
/// Technical details:
///     On thread safety and use of `@synchronized`:
///         We use `@synchronized(observedObject)`in 3 places and `pthread_mutex` in 1 place inside this implementation to ensure thread-safety. All functions and methods exposed through the interface should be thread safe.
///         Generally, when making things thread-safe I was thinking about:
///             What are the shared mutable resources, and how can we ensure that when they are being mutated, nothing else is accessing or trying to mutate them at the same time. It also helps to think about the big-picture control flow - we don't need to do finegrained locking and unlocking everywhere, if we can just ensure that, when the control flow enters Observe.m, then, before any shared state encapsulated by Observe.m is mutated or read, a lock is always acquired - then we're good! Since the control flow and interface for Obseve.m is relatively simple, that makes things relatively managable. Deadlocks can be avoided by ensuring that you never try to acquire another lock while you already hold a lock. (so you probably shouldn't invoke a callback with foreign code while holding your lock, since it might try to acquire further locks).
///
/// Conclusion: Should we use this?
///     - This adds a light "reactive style" convenience interface on top of kvo.
///     - It's available in objc which I like writing more than swift.
///     - It's usually slightly faster than combine but in the same ballpark.  For performance critical things, you'd still want to use simple function calls since they are much faster, and for UI stuff the performance difference doesn't matter.
///         - Actually, when using Combine as a wrapper for kvo, using `someObject.publisher(for:<keyPath>)`, then Combine is around 3-6x slower than our code in our tests, but for UI Stuff this still probably doesn't matter.
///     - I wrote it and control it so I might understand how to use it better.
///     - I have a general dislike for Swift and all this fancy magic abstraction stuff. But this doesn't really matter, I could get used to either.
///     - The build times for MMF 3 are quite slow. And I suspect that swift is a big factor in that.
///         > I might want to move away from Swift and write more of the UI Stuff in objc. And this might enable that. Some of the main reasons we use so much swift is that we wanted to use reactive patterns for the UI of MMF, which lead us to include the ReactiveSwift framework and build much of the UI code in Swift. MMF 2 which was pure objc iirc, had much faster build times iirc.
///     - BIG CON: This needs to be thread safe. I tried but thread safety is hard. If there are subtle bugs in this, we might make the app less stable vs using an established framework or API.
///         Update: I thought about it again and I'm pretty confident this is thread safe now. There are only a small number of paths through which the control flow can enter the core logic of this file:
///             `blobs_add_observer()`, `blobs_cancel_observer()`, `[BlockObserver dealloc]`, `observeValueForKeyPath:ofObject:change:context:`, and the callback inside `addBlockObserversForLatestValues()`. If we ensure that all these entry points are thread-safe, which we did, then entire file should be thread safe to use. Maybe I missed something but I think it's not too bad to make this thread safe after all.
///
///     -> Overall this was a cool experiment. It was fun and I learned a bunch of things. Maybe we can adopt this into MMF at some point, but we should probably only adopt it for a new major release where we can thoroughly test this before rolling it out to non-beta users.
///
///     Other takeaways:
///     - Due to the Benchmarks we made for this I saw that, for simple arithmetic and function calling, pure swift seems to be around 4 - 6x faster than our pure C code!! That's incredible and very unexpected.
///         Unfortunately, when you use frameworks or higher level datatypes with Swift, and interoperate with objc, that can sometimes slow things down a lot in unpredictable ways. (See the whole `SWIFT_UNBRIDGED` hassle in MMF., or Combine being 6x slower when used with KVO) Objc/C and its frameworks seem more predictable and consistent to me. But for really low level routines or if you use it right, swift can actually be incredibly fast, which is cool and good to know, and makes me like the language a bit more.
///
/// Update:
///     I just spent a while trying to move MMF to using this, and it's quite a lot of work, definitely a few-days refactor. Also, questionable whether combine would be a better choice than this (Combine API might be a bit shorter / cleaner, and easier to translate from ReactiveSwift, and we'd still be removing a library dependency which should speed up builds. It would be sort of nice to move the UI code away from swift to further improve build times but that would be way too much work! We're stuck with Swift for now.
///
/// Update: [Apr 2025]
///     - This is sort of a reimplementation of Swift's `observe(_:options:changeHandler:)`, but that only supports Swift keypaths which are super annoying IIRC.
///         - `observe(_:options:changeHandler:)` Has the observation retain the object, while we have the object retain the observation (aka BlockObserver object). Ours is more convenient, but might be slower (due to weak ref from BlockObserver to observed objc) and perhaps more error-prone regarding retain-cycles.
///

#pragma mark - Constants
/// Define context
///     Kind of unncecessary. The context in the KVO framework is designed for when a superclass also observes the same keyPath on the same object and that can't happen here.
static void *_BlockObserverKVOContext = "mfBlockObserverContext";

#pragma mark - BlockObserver class
/// [Apr 2025] We try to put as little into this as possible and as much as possible in the `Core C "Glue Code"` below – I think that makes things clearer.

@interface BlockObserver ()
@end

@implementation BlockObserver  {
    
    /// Immutables
    ///     These shouldn't change after initialization
    /// Notes:
    /// - Retain cycles will occur if `callbackBlock` captures the observed object. This clients need to use weak/strong dance to avoid. (Use @weakify and @strongify)
    /// - weakObservedObject being weak actually makes this noticable slower since we always need to unwrap it and check for nil
    @public NSObject                    *__weak _weakObservedObject;   /// Making the ivars public bc I just learned that that's possible. Not sure why we're using ivars vs properties. I guess speed?
    @public NSString                    *_observedKeyPath;
    @public NSKeyValueObservingOptions  _observingOptions;
    @public id                          _callbackBlock;
    
    /// Mutables
    @public BOOL                        _observationCount;              /// This state mostly exists to validate that we're producing balanced calls to the add/remove methods.
}

- (void)observeValueForKeyPath:(NSString *)keyPath ofObject:(id)object change:(NSDictionary *)change context:(void *)context {
        
    /// Handle KVO callback
        
    /// Thread safe
    ///     As we're not interacting with any shared mutable state.
    
    /// This function is called when the observed value changes.
    
    /// Guard context
    if (context != _BlockObserverKVOContext) {
        assert(false); /// [Apr 2025] Don't think this can happen?
        [super observeValueForKeyPath:keyPath ofObject:object change:change context:context];
        return;
    }
    
    /// Parse options
    BOOL receivesOldAndNewValues =  (self->_observingOptions & NSKeyValueObservingOptionNew)  &&
                                    (self->_observingOptions & NSKeyValueObservingOptionOld)  ;
    /// Extract new and old values
    NSObject *newValue = change[NSKeyValueChangeNewKey];
    NSObject *oldValue = receivesOldAndNewValues ? change[NSKeyValueChangeOldKey] : nil;
    
    /// Validate
#if DEBUG
    
    /// Validate options
    assert(self->_observingOptions & NSKeyValueObservingOptionNew);
    
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
    if (receivesOldAndNewValues)    ((ObservationCallbackBlockWithOldAndNew)self->_callbackBlock)(oldValue, newValue);
    else                            ((ObservationCallbackBlockWithNew)self->_callbackBlock)(newValue);
    
}

static void blobs_cancel_observer(BlockObserver *blockObserver); /// Forward-declaration

- (void)dealloc {
    
    /// Remove observation on dealloc
    ///     We don't need to worry about what happens if the observedObject is dealloced before the BlockObserver, since in that case, KVO will automatically remove the observation in macOS 11 Big Sur and later. See SO answer by Rob Mayoff: https://stackoverflow.com/a/18065286/10601702. This is great since we tried doing the same thing using the DeallocTracker and it was quite hacky and I don't think it worked.
    ///     I'm not even sure that calling `blobs_cancel_observer()` here is necessary. Maybe the system also handles that. Would kinda make sense.
    ///
    /// Note: [Apr 2025] `blobs_cancel_observer()` tries to unwrap weak ref to `_weakObservedObject`. If that fails, it just returns. That makes sense, since in that case, the observed object was already dealloc'ed and therefore the observation has been removed by the system already.
    
    blobs_cancel_observer(self); /// Thread-safe
}

@end

#pragma mark - Core C Glue Code

/// Should be thread safe
///     and therefore all the interface functions below should also be threadsafe since they are just wrappers around this.

static NSMutableSet *blobs_get_observers(NSObject *observableObject) {
    
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

static BOOL blobs_observer_is_active(BlockObserver *observer) {
    /// Should be thread safe. I guess the three different base values could change while we're retrieving them, but that shouldn't lead to any invalid results, so it's ok. We are weirdly declaring this here instead of inside the BlockObserver class definition because we want the interface methods below to be strictly simple wrappers around the `Core C Glue Code`, then we just need to ensure the `Core C Glue Code` is thread safe and the whole interface will be safe as well!
    return  observer->_observationCount > 0     &&
            (observer->_weakObservedObject != nil);
}

static BlockObserver *blobs_add_observer(NSObject *observableObject, NSString *keyPath, BOOL receiveInitialValue, BOOL receiveOldAndNewValues, ObservationCallbackBlock callback) {
    
    /// Thread safe
    
    @synchronized (observableObject) {
        
        /// Create & init blockObserver
        BlockObserver *blockObserver = [[BlockObserver alloc] init];
        ({
            /// Set up options
            NSKeyValueObservingOptions options = NSKeyValueObservingOptionNew;
            options = options | (receiveOldAndNewValues ? NSKeyValueObservingOptionOld      : 0);
            options = options | (receiveInitialValue    ? NSKeyValueObservingOptionInitial  : 0);
            
            /// Store args
            blockObserver->_weakObservedObject  = observableObject;
            blockObserver->_observedKeyPath     = keyPath;
            blockObserver->_observingOptions    = options;
            blockObserver->_callbackBlock       = callback;
            
            /// Init other state
            blockObserver->_observationCount = 1;
        });
        
        /// Add blockObserver to object
        ///     Now it is retained and the client won't have to retain it for the observation to stay active.
        [blobs_get_observers(observableObject) addObject:blockObserver];
        
        /// Start the blockObserver
        [observableObject addObserver:blockObserver forKeyPath:blockObserver->_observedKeyPath options:blockObserver->_observingOptions context:_BlockObserverKVOContext];
        
        /// Return blockObserver
        ///     Primarily intended as a handle to let the client cancel the observation
        return blockObserver;
    }
}

static void blobs_cancel_observer(BlockObserver *blockObserver) {
    
    /// Thread safe
    
    /// Get & unwrap observedObject
    NSObject *strongObservedObject = blockObserver->_weakObservedObject;
    if (strongObservedObject == nil) {
        return; /// If the observedObject is already nil it will already have stopped the observation and released the blockObserver already.
    }
    
    @synchronized (strongObservedObject) {
        
        /// Guard multiple cancelations
        if (blockObserver->_observationCount <= 0)      { assert(false); return; }
        blockObserver->_observationCount -= 1;
        
        /// Remove observer
        [strongObservedObject removeObserver:blockObserver forKeyPath:blockObserver->_observedKeyPath context:_BlockObserverKVOContext];
        
        /// Release the blockObserver
        ///     It should then normally be dealloced, unless its retained by an outsider.
        ///     [Apr 2025] The deallocation will cause this function to be called *again* which is a bit inefficient. Maybe we could use a recursion tracking (with `static __thread` variable) to speed that up?
        [blobs_get_observers(strongObservedObject) removeObject:blockObserver];
    }
}

static void blobs_cancel_observers(NSArray<BlockObserver *> *blockObservers) {
    
    /// Thread safe
    
    for (BlockObserver *observer in blockObservers) {
        blobs_cancel_observer(observer);
    }
}

#pragma mark - Main Interface

/// This is a pure wrapper around the `Core C Glue Code` functions defined above.
///     Since that is thread safe, this should also be thread safe.

@implementation NSObject (MFBlockObservationInterface)

- (BlockObserver *)observe:(NSString *)keyPath withBlock:(ObservationCallbackBlockWithNew)callbackBlock {
    BOOL receiveInitialValue = YES;
    BOOL receiveOldAndNewValues = NO;
    return blobs_add_observer(self, keyPath, receiveInitialValue, receiveOldAndNewValues, callbackBlock);
}

- (BlockObserver *)observe:(NSString *)keyPath receiveInitialValue:(BOOL)receiveInitialValue receiveOldAndNewValues:(BOOL)receiveOldAndNewValues withBlock:(ObservationCallbackBlock)callbackBlock {
    return blobs_add_observer(self, keyPath, receiveInitialValue, receiveOldAndNewValues, callbackBlock);
}

@end

@implementation BlockObserver (MFBlockObservationInterface)

- (BOOL)observationIsActive                                         { return blobs_observer_is_active(self); }
- (void)cancelObservation                                           { blobs_cancel_observer(self); }
+ (void)cancelObservations:(NSArray<BlockObserver *> *)observers    { blobs_cancel_observers(observers); }

@end

#pragma mark - ObserveLatest

#pragma mark Core implementation

static NSArray<BlockObserver *> *addBlockObserversForLatestValues(NSArray<NSObject *> *objects, NSArray<NSString *> *keyPaths, ObservationCallbackBlockWithLatest callbackBlock) {
    
    /// Thread safety:
    ///     The core function we call, `blobs_add_observer()` is thread safe, the only shared state we handle - the latestValueCache - is locked with a mutex, so thread safe.
    ///         What happens inside the callbackBlock is not our responsibility.
    ///
    /// Memory safety:
    ///     The callbackBlock will be retained by each object in `objects`. If any of them are retained/captured in the callbackBlock there's a retain cycle!
    ///     The latestValues are only referenced as weak pointers to help with preventing retain cycles. Since we don't retain them, it's the clients responsibility to make sure that the latestValues are not deallocated during observation (e.g. by retaining the observed`objects`). If an object becomes deallocated during observation, its latest value might also become deallocated, and will appear as 'nil' in the callbackBlock.
    ///
    /// Why use 9 local variables for the latestValueCache?
    ///     - Using an NSArray won't let us reference the values weakly, leading to unavoidable retain cycles in some scenarios (When one of the latest values retains one of the observedObjects)
    ///     - Using an NSPointerArray lets us reference latestValues weakly. But using it made performance measurably worse. (IIRC)
    ///     - Update: [Apr 2025] Cleaned things up by using C array instead. (Had to wrap it in struct, see below.)
    
    /// Declare convenience macros
    ///     TODO: Replace these with macros from our mac-mouse-fix utility headers
    #define arrcount(arr) \
        (sizeof(arr)/sizeof((arr)[0]))
    #define loopc(varname, count) \
        for (int64_t varname = 0; varname < count; varname++)
    
    /// Constants
    const int indexForWhichToReceiveInitialCallback = 0;
    const int nmax = 9;
    
    /// Extract
    int n = (int)objects.count;
    
    /// Validate
    assert(keyPaths.count == objects.count);
    assert(n <= nmax);
    
    /// Declare result
    NSMutableArray<BlockObserver *> *observers = [NSMutableArray array];
    
    /// Create cache
    ///     Trick: wrap stack array in struct to make clang capture it in the block. (It doesn't allow capturing arrays directly for 'performance reasons' – See: https://lists.llvm.org/pipermail/cfe-dev/2013-June/030246.html)
    typedef struct { __weak id _[nmax]; } LatestValueCache;
    __block LatestValueCache latestValueCache;
    
    /// Init cache
    loopc(i, nmax)
        latestValueCache._[i] = (i >= n || i == indexForWhichToReceiveInitialCallback) ?
                                nil :
                                [objects[i] valueForKeyPath:keyPaths[i]];
    
    /// Create mutex token for cache access
    __block id cache_sync_token = @"the_sync_token";
    
    loopc(i, n) {
        
        /// Iterate objects
        
        /// Define params
        ///     Note: Only receive initialValue on one object, so the `callbackBlock` doesn't receive the same initial values n times.
        BOOL doReceiveInitialValue = i == indexForWhichToReceiveInitialCallback;
        BOOL receiveOldAndNewValues = NO;
        
        /// Create observer
        BlockObserver *blockObserver = blobs_add_observer(objects[i], keyPaths[i], doReceiveInitialValue, receiveOldAndNewValues, ^void (NSObject *newValue) {
            
            /// Note: If we capture any of the `objects` here (or in `callbackBlock`) that's a retain cycle!
            
            /// Acquire lock
            objc_sync_enter(cache_sync_token);
            
            /// Update cache
            ///     On  concurrency: We want to lock cache updates and retrievals to avoid race conditions, however, we don't want to lock around the callbackBlock invocation since depending on what the callback code does it could cause deadlocks.
            latestValueCache._[i] = newValue;
        
            /// Retrieve cache
            ///     Get a local, strong ref to each cache variable while we still have the lock
            __strong id retrievedLatestValues[n];
            loopc(j, n)
                retrievedLatestValues[j] = latestValueCache._[j];
            
            /// Release lock
            ///     Note: We could invoke the callbackBlock while we still hold the lock, then we could skip the cache-retrieval step, possibly speeding things up a bit. But that could lead to deadlocks depending on what the callbackBlock code does.
            objc_sync_exit(cache_sync_token);
            
            /// Call the callback
            #define getCache(__index) \
                retrievedLatestValues[__index]
            if      (n == 2) ((ObservationCallbackBlockWithLatest2)callbackBlock)((int)i, getCache(0), getCache(1));
            else if (n == 3) ((ObservationCallbackBlockWithLatest3)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2));
            else if (n == 4) ((ObservationCallbackBlockWithLatest4)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3));
            else if (n == 5) ((ObservationCallbackBlockWithLatest5)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3), getCache(4));
            else if (n == 6) ((ObservationCallbackBlockWithLatest6)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3), getCache(4), getCache(5));
            else if (n == 7) ((ObservationCallbackBlockWithLatest7)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3), getCache(4), getCache(5), getCache(6));
            else if (n == 8) ((ObservationCallbackBlockWithLatest8)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3), getCache(4), getCache(5), getCache(6), getCache(7));
            else if (n == 9) ((ObservationCallbackBlockWithLatest9)callbackBlock)((int)i, getCache(0), getCache(1), getCache(2), getCache(3), getCache(4), getCache(5), getCache(6), getCache(7), getCache(8));
            else assert(false);
            #undef getCache
        });
        
        /// Store the new observer
        [observers addObject:blockObserver];
    }
    
    /// Return
    return observers;
}

#pragma mark Interface

@implementation BlockObserver (MFBlockObservationInterface_LatestValues)

+ (NSArray<BlockObserver *> *)observeLatest:(NSArray<NSArray *> *)objectsAndKeyPaths onQueue:(dispatch_queue_t _Nullable)dispatchQueue withBlock:(ObservationCallbackBlockWithLatest)callbackBlock {
    
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
    return addBlockObserversForLatestValues(objects, keyPaths, callbackBlock);
}

+ (NSArray<BlockObserver *> *)observeLatest2:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest2)callbackBlock { assert(objectsAndKeypaths.count == 2); return [self observeLatest:objectsAndKeypaths onQueue:nil withBlock:callbackBlock]; }
+ (NSArray<BlockObserver *> *)observeLatest3:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest3)callbackBlock { assert(objectsAndKeypaths.count == 3); return [self observeLatest:objectsAndKeypaths onQueue:nil withBlock:callbackBlock]; }
+ (NSArray<BlockObserver *> *)observeLatest4:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest4)callbackBlock { assert(objectsAndKeypaths.count == 4); return [self observeLatest:objectsAndKeypaths onQueue:nil withBlock:callbackBlock]; }
+ (NSArray<BlockObserver *> *)observeLatest5:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest5)callbackBlock { assert(objectsAndKeypaths.count == 5); return [self observeLatest:objectsAndKeypaths onQueue:nil withBlock:callbackBlock]; }
+ (NSArray<BlockObserver *> *)observeLatest6:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest6)callbackBlock { assert(objectsAndKeypaths.count == 6); return [self observeLatest:objectsAndKeypaths onQueue:nil withBlock:callbackBlock]; }
+ (NSArray<BlockObserver *> *)observeLatest7:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest7)callbackBlock { assert(objectsAndKeypaths.count == 7); return [self observeLatest:objectsAndKeypaths onQueue:nil withBlock:callbackBlock]; }
+ (NSArray<BlockObserver *> *)observeLatest8:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest8)callbackBlock { assert(objectsAndKeypaths.count == 8); return [self observeLatest:objectsAndKeypaths onQueue:nil withBlock:callbackBlock]; }
+ (NSArray<BlockObserver *> *)observeLatest9:(NSArray<NSArray *> *)objectsAndKeypaths withBlock:(ObservationCallbackBlockWithLatest9)callbackBlock { assert(objectsAndKeypaths.count == 9); return [self observeLatest:objectsAndKeypaths onQueue:nil withBlock:callbackBlock]; }

@end
