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
#import "EXTScope.h"
#import "KVOMutationSupport.h"
@import QuartzCore;
@import AppKit;

#define stringf(format, args...) [NSString stringWithFormat:format, args]

MFDataClass(TestObject, (@property (nonatomic) NSInteger value;))

MFDataClass(TestObject4, (@property (nonatomic) NSInteger value1;
                          @property (nonatomic) NSInteger value2;
                          @property (nonatomic) NSInteger value3;
                          @property (nonatomic) NSInteger value4;))

MFDataClass(TestStrings, (MFDataProp(NSMutableString *string1)
                          MFDataProp(NSMutableString *string2)));

static BlockObserver *_memoryTestVariable = nil;

@implementation BlockObserverBenchmarks

void runBlockObserverBenchmarks(void) {
        
    @autoreleasepool {
        
        int iterations = 1000000;
        
        CFTimeInterval combineTime = NAN;
        CFTimeInterval kvoTime = NAN;
        CFTimeInterval pureObjcTime = NAN;
        CFTimeInterval pureSwiftTime = NAN;
        
        NSLog(@"Running simple tests with %d iterations", iterations);
        
            combineTime = [BlockObserverBenchmarksSwift runCombineTestWithIterations:iterations];
            kvoTime = runKVOTest(iterations);
            pureObjcTime = runPureObjcTest(iterations);
            pureSwiftTime = [BlockObserverBenchmarksSwift runPureSwiftTestWithIterations:iterations];
        
        NSLog(@"Combine time: %f", combineTime);
        NSLog(@"kvo time: %f", kvoTime);
        NSLog(@"pure objc time: %f", pureObjcTime);
        NSLog(@"pure swift time: %f", pureSwiftTime);
        NSLog(@"pureSwift is %.2fx faster than pureObjc. pureObjc is %.2fx faster than kvo. kvo is %.2fx faster than Combine", pureObjcTime  / pureSwiftTime , kvoTime / pureObjcTime , combineTime / kvoTime);
        
        iterations = iterations / 4;
        
        NSLog(@"Running combineLatest tests with %d iterations", iterations);
        
            combineTime = [BlockObserverBenchmarksSwift runCombineTest_ObserveLatestWithIterations:iterations];
        kvoTime = runKVOTest_ObserveLatest(iterations);
            pureObjcTime = runPureObjcTest_ObserveLatest(iterations);
            pureSwiftTime = [BlockObserverBenchmarksSwift runPureSwiftTest_ObserveLatestWithIterations:iterations];
        
        NSLog(@"Combine time: %f", combineTime);
        NSLog(@"kvo time: %f", kvoTime);
        NSLog(@"pureObjc time: %f", pureObjcTime);
        NSLog(@"pureSwift time: %f", pureSwiftTime);
        NSLog(@"pureSwift is %.2fx faster than pureObjc. pureObjc is %.2fx faster than kvo. kvo is %.2fx faster than Combine", pureObjcTime / pureSwiftTime , kvoTime / pureObjcTime, combineTime / kvoTime);
        
        iterations = iterations/2;
        
        NSLog(@"Running string manipulation tests with %d iterations", iterations);
        
            combineTime = [BlockObserverBenchmarksSwift runCombineTest_StringsWithIterations:iterations];
            kvoTime = runKVOTest_Strings(iterations);
            pureObjcTime = runPureObjcTest_Strings(iterations);
        
        NSLog(@"Combine time: %f", combineTime);
        NSLog(@"kvo time: %f", kvoTime);
        NSLog(@"pureObjc time: %f", pureObjcTime);
        NSLog(@"kvo is %.2fx faster than Combine", combineTime / kvoTime);
        
    } /// End of autoreleasePool
    
    /// Idle after  autoreleasePool to look at memery graph
    ///     See if there are memory leaks
    NSLog(@"Idling an a runLoop...");
    
    [_memoryTestVariable cancelObservation];
    CFRunLoopRunInMode(0, 2.0, false);
    @autoreleasepool {
        _memoryTestVariable = nil;
    }
    CFRunLoopRun();
//    exit(0);
}

NSTimeInterval runPureObjcTest(NSInteger iterations) {
    
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
    NSLog(@"pureObjc - count: %ld, sum: %ld", valuesFromCallback.count, (long)sumFromCallback);
    
    /// Return
    CFTimeInterval testDuration = endTime - startTime;
    return testDuration;
}

NSTimeInterval runKVOTest(NSInteger iterations) {
    
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
    NSLog(@"KVO - count: %ld, sum: %ld", valuesFromCallback.count, (long)sumFromCallback);
    
    /// Return
    CFTimeInterval testDuration = endTime - startTime;
    return testDuration;
}


NSTimeInterval runPureObjcTest_ObserveLatest(NSInteger iterations) {
    
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
    
    NSLog(@"pureObjc - ObserveLatest - sum: %ld", (long)sumFromCallback);
    
    return endTime - startTime;
}

NSTimeInterval runKVOTest_ObserveLatest(NSInteger iterations) {
    
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
    
    NSLog(@"KVO - ObserveLatest - sum: %ld", (long)sumFromCallback);
    
    return endTime - startTime;
}

NSTimeInterval runKVOTest_Strings(NSInteger iterations) {
    
    CFTimeInterval startTime = CACurrentMediaTime();
    __block NSInteger checkSum = 0;
    
    TestStrings *testObject = [[TestStrings alloc] init];
    testObject.string1 = [NSMutableString stringWithString:@"Hello"];
    testObject.string2 = [NSMutableString stringWithString:@"World"];
    
    [testObject.string1 notifyOnMutation:YES];
    [testObject.string2 notifyOnMutation:YES];
    
    [testObject.string2 observeUpdates:@"self" withBlock:^(NSString * updatedString2) {
        uint16_t lastChar = (uint16_t)[updatedString2 characterAtIndex:updatedString2.length - 1];
        checkSum += lastChar;
    }];
    
    @weakify(testObject);
    _memoryTestVariable = [testObject.string1 observeUpdates:@"self" withBlock:^(NSString *_Nonnull updatedString1) {
        @strongify(testObject);
        
        NSInteger lastIndex = testObject.string1.length - 1;
        uint16_t lastChar = (uint16_t)[updatedString1 characterAtIndex:lastIndex];
        
        [testObject.string2 appendString:stringf(@"%d", lastChar + 1)];
        [testObject.string2 appendString:stringf(@"%d", lastChar + 2)];
    }];
    
    for (NSInteger i = 0; i < iterations; i++) {
        
        [testObject.string1 appendString:stringf(@"%ld", (long)i)];
    }
    
    CFTimeInterval endTime = CACurrentMediaTime();
    NSLog(@"KVO - strings - count: %ld, checksum: %ld", iterations, checkSum);
    
    return endTime - startTime;
}
NSTimeInterval runPureObjcTest_Strings(NSInteger iterations) {
    
    CFTimeInterval startTime = CACurrentMediaTime();
    __block NSInteger checkSum = 0;
    
    TestStrings *testObject = [[TestStrings alloc] init];
    testObject.string1 = [NSMutableString stringWithString:@"Hello"];
    testObject.string2 = [NSMutableString stringWithString:@"World"];
    
    void (^string2MutationCallback)(NSString *) =  ^(NSString *updatedString2){
        uint16_t lastChar = (uint16_t)[updatedString2 characterAtIndex:updatedString2.length - 1];
        checkSum += lastChar;
    };
    
    void (^string1MutationCallback)(NSString *) = ^(NSString *updatedString1) {
        
        NSInteger lastIndex = testObject.string1.length - 1;
        uint16_t lastChar = (uint16_t)[updatedString1 characterAtIndex:lastIndex];
        
        [testObject.string2 appendFormat:@"%d", lastChar + 1];
        string2MutationCallback(testObject.string2);
        [testObject.string2 appendFormat:@"%d", lastChar + 2];
        string2MutationCallback(testObject.string2);
    };
    
    for (NSInteger i = 0; i < iterations; i++) {
        [testObject.string1 appendFormat:@"%ld", (long)i];
        string1MutationCallback(testObject.string1);
    }
    
    CFTimeInterval endTime = CACurrentMediaTime();
    NSLog(@"pureObjc - strings - count: %ld, checksum: %ld", iterations, checkSum);
    
    return endTime - startTime;
}


@end
