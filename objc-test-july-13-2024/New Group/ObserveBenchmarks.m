//
//  BlockObserverBenchmarks.m
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 31.07.24.
//

#import "ObserveBenchmarks.h"
#import "MFDataClass.h"
#import "Observe.h"
#import "objc_test_july_13_2024-Swift.h"
@import QuartzCore;

MFDataClass(TestObject, (
                         @property (nonatomic) NSInteger value;
                         ))
MFDataClass(TestObject4, (
                          @property (nonatomic) NSInteger value1;
                          @property (nonatomic) NSInteger value2;
                          @property (nonatomic) NSInteger value3;
                          @property (nonatomic) NSInteger value4;
                         ))

@implementation BlockObserverBenchmarks

void runBlockObserverBenchmarks(void) {
        
    int iterations = 1000000;

    CFTimeInterval combineTime = NAN;
    CFTimeInterval kvoTime = NAN;
    CFTimeInterval pureObjcTime = NAN;
    CFTimeInterval pureSwiftTime = NAN;
    
    NSLog(@"Running simple tests with %d iterations", iterations);
    
    combineTime = [BlockObserverBenchmarksSwift runCombineTestWithIterations:iterations];
    kvoTime = runObjcTest(iterations);
    pureObjcTime = runPrimitiveTest(iterations);
    pureSwiftTime = [BlockObserverBenchmarksSwift runPrimitiveSwiftTestsWithIterations:iterations];
    
    NSLog(@"Combine time: %f", combineTime);
    NSLog(@"kvo time: %f", kvoTime);
    NSLog(@"primitive objc time: %f", pureObjcTime);
    NSLog(@"primitive swift time: %f", pureSwiftTime);
    NSLog(@"swift is %fx faster than objc. objc is %fx faster than kvo. kvo is %fx faster than Combine -- swift is %fx faster than Combine", pureObjcTime  / pureSwiftTime , kvoTime / pureObjcTime , combineTime / kvoTime, combineTime / pureSwiftTime);
    
    iterations = iterations / 4;
    
    NSLog(@"Running combineLatest tests with %d iterations", iterations);
    
    combineTime = [BlockObserverBenchmarksSwift runCombineTest_ObserveLatestWithIterations:iterations];
    kvoTime = runObjcTest_ObserveLatest(iterations);
    pureObjcTime = runPrimitiveTest_ObserveLatest(iterations);
    pureSwiftTime = [BlockObserverBenchmarksSwift runPrimitiveSwiftTest_ObserveLatestWithIterations:iterations];
    
    NSLog(@"Combine time: %f", combineTime);
    NSLog(@"kvo time: %f", kvoTime);
    NSLog(@"primitive objc time: %f", pureObjcTime);
    NSLog(@"primitive swift time: %f", pureSwiftTime);
    NSLog(@"swift is %fx faster than objc. objc is %fx faster than kvo. kvo is %fx faster than Combine -- swift is %fx faster than Combine", pureObjcTime / pureSwiftTime , kvoTime / pureObjcTime, combineTime / kvoTime, combineTime / pureSwiftTime);
    
    /// Run runloop to see if deallocing works?
//    CFRunLoopRun();
    exit(0);
}

NSTimeInterval runPrimitiveTest(NSInteger iterations) {
    
    /// Don't use observation
    
    /// Ts
    CFTimeInterval startTime = CACurrentMediaTime();
    
    /// Mutable data
    
    NSInteger value = 0;
    NSMutableArray *valuesFromCallback = [NSMutableArray array];
    __block NSInteger sumFromCallback = 0;

    
    /// Setup callback
    void (^callback)(NSInteger newValue) = ^(NSInteger newValue){
        [valuesFromCallback addObject:@(newValue)];
        sumFromCallback += newValue;
        if (newValue % 2 == 0) {
            sumFromCallback <<= 2;
        }
    };
    
    /// Change value
    for (NSInteger i = 0; i < iterations; i++) {
        value = i;
        callback(value);
    }
    
    /// Ts
    CFTimeInterval endTime = CACurrentMediaTime();
    
    /// Log
    NSLog(@"primitive count: %ld, sum: %ld", valuesFromCallback.count, (long)sumFromCallback);
    
    /// Return
    CFTimeInterval testDuration = endTime - startTime;
    return testDuration;
}

NSTimeInterval runObjcTest(NSInteger iterations) {
    
    /// Ts
    CFTimeInterval startTime = CACurrentMediaTime();
    
    /// Mutable data
    NSMutableArray *valuesFromCallback = [NSMutableArray array];
    __block NSInteger sumFromCallback = 0;
    
    /// Setup callback
    TestObject *testObject = [[TestObject alloc] init];
    [testObject observe:@"value" withBlock:^(NSObject * _Nonnull newValueBoxed) {
        NSInteger newValue = unboxNSValue(NSInteger, newValueBoxed);
        [valuesFromCallback addObject:newValueBoxed];
        sumFromCallback += newValue;
        if (newValue % 2 == 0) {
            sumFromCallback <<= 2;
        }
    }];
    
    /// Change value
    for (NSInteger i = 0; i < iterations; i++) {
        testObject.value = i;
    }
    
    /// Ts
    CFTimeInterval endTime = CACurrentMediaTime();
    
    /// Log
    NSLog(@"objc count: %ld, sum: %ld", valuesFromCallback.count, (long)sumFromCallback);
    
    /// Return
    CFTimeInterval testDuration = endTime - startTime;
    return testDuration;
}


NSTimeInterval runPrimitiveTest_ObserveLatest(NSInteger iterations) {
    
    CFTimeInterval startTime = CACurrentMediaTime();
    
    __block NSInteger sumFromCallback = 0;
    
    NSInteger v1 = 0;
    NSInteger v2 = 0;
    NSInteger v3 = 0;
    NSInteger v4 = 0;
    
    void (^callback)(NSInteger, NSInteger, NSInteger, NSInteger) = ^(NSInteger value1, NSInteger value2, NSInteger value3, NSInteger value4) {
        
        sumFromCallback += value1 + value2 + value3 + value4;
        if ((value1 + value2 + value3 + value4) % 2 == 0) {
            sumFromCallback <<= 8;
        }
    };
    
    for (NSInteger i = 1; i < iterations; i++) {
        v1 = i;
        callback(v1, v2, v3, v4);
        v2 = i * 2;
        callback(v1, v2, v3, v4);
        v3 = i * 3;
        callback(v1, v2, v3, v4);
        v4 = i * 4;
        callback(v1, v2, v3, v4);
    }
    
    CFTimeInterval endTime = CACurrentMediaTime();
    
    NSLog(@"ObserveLatest primitive sum: %ld", (long)sumFromCallback);
    
    return endTime - startTime;
}

NSTimeInterval runObjcTest_ObserveLatest(NSInteger iterations) {
    
    CFTimeInterval startTime = CACurrentMediaTime();
    
    __block NSInteger sumFromCallback = 0;
    
    TestObject4 *testObject = [[TestObject4 alloc] init];
    
    [BlockObserver observeLatest4:@[@[testObject, @"value1"],
                                    @[testObject, @"value2"],
                                    @[testObject, @"value3"],
                                    @[testObject, @"value4"]]
     
                        withBlock:^(int updatedIndex, NSObject * _Nullable v1, NSObject * _Nullable v2, NSObject * _Nullable v3, NSObject * _Nullable v4) {
        
        NSInteger value1 = unboxNSValue(NSInteger, v1);
        NSInteger value2 = unboxNSValue(NSInteger, v2);
        NSInteger value3 = unboxNSValue(NSInteger, v3);
        NSInteger value4 = unboxNSValue(NSInteger, v4);
        
        sumFromCallback += value1 + value2 + value3 + value4;
        if ((value1 + value2 + value3 + value4) % 2 == 0) {
            sumFromCallback <<= 8;
        }
    }];
    
    for (NSInteger i = 1; i < iterations; i++) {
        testObject.value1 = i;
        testObject.value2 = i * 2;
        testObject.value3 = i * 3;
        testObject.value4 = i * 4;
    }
    
    CFTimeInterval endTime = CACurrentMediaTime();
    
    NSLog(@"ObserveLatest objc sum: %ld", (long)sumFromCallback);
    
    return endTime - startTime;
}

@end
