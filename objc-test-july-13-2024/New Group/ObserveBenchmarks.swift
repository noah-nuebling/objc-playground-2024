//
//  BlockObserverBenchmarks.swift
//  objc-test-july-13-2024
//
//  Created by Noah Nübling on 31.07.24.
//

import Foundation
import Combine
import QuartzCore

class TestObjectSwift: NSObject {
    @objc dynamic var value: Int = 0
}
class TestObjectSwift4: NSObject {
    @objc dynamic var value1: Int = 0
    @objc dynamic var value2: Int = 0
    @objc dynamic var value3: Int = 0
    @objc dynamic var value4: Int = 0
}


@objc class BlockObserverBenchmarksSwift: NSObject {
    
    @objc class func runPrimitiveSwiftTests(iterations: Int) -> TimeInterval {
        
        /// Ts
        let startTime = CACurrentMediaTime()
        
        /// MutableData
        var valuesFromCallback = [Int]()
        var sumFromCallback = 0
        
        /// Setup callback
        var value1 = 0
        let callback =  { (newValue: Int) in
            valuesFromCallback.append(newValue)
            sumFromCallback += newValue
            if (newValue % 2 == 0) {
                sumFromCallback <<= 2
            }
        }
        /// Change value
        for i in 0..<iterations {
            value1 = i
            callback(value1)
        }
        
        /// Ts
        let endTime = CACurrentMediaTime()
        
        /// Log
        print("Primitive swift count: \(valuesFromCallback.count), sum: \(sumFromCallback)")
        
        /// Return bench time
        return endTime - startTime
    }
    
    @objc class func runCombineTest(iterations: Int) -> TimeInterval {
        
        /// Ts
        let startTime = Date()
        
        /// MutableData
        var valuesFromCallback = [Int]()
        var sumFromCallback = 0
        
        /// Setup callback
        let testObject = TestObjectSwift()
        let cancellable = testObject.publisher(for: \.value)
            .sink { newValue in
                valuesFromCallback.append(newValue)
                sumFromCallback += newValue
                if (newValue % 2 == 0) {
                    sumFromCallback <<= 2
                }
            }
        
        /// Change value
        for i in 0..<iterations {
            testObject.value = i
        }
        
        /// Ts
        let endTime = Date()
        
        /// Log
        print("Combine count: \(valuesFromCallback.count), sum: \(sumFromCallback)")
        
        /// Return bench time
        return endTime.timeIntervalSince(startTime)
    }
    
    @objc class func runPrimitiveSwiftTest_ObserveLatest(iterations: Int) -> TimeInterval {
        
        let startTime = CACurrentMediaTime()
        
        var sumFromCallback = 0
        
        var v1 = 0
        var v2 = 0
        var v3 = 0
        var v4 = 0
        
        let callback = { (value1, value2, value3, value4) in
            sumFromCallback += value1 + value2 + value3 + value4
            if (value1 + value2 + value3 + value4) % 2 == 0 {
                sumFromCallback <<= 8
            }
        }
        
        for i in 1..<iterations {
            v1 = i
            callback(v1, v2, v3, v4)
            v2 = i * 2
            callback(v1, v2, v3, v4)
            v3 = i * 3
            callback(v1, v2, v3, v4)
            v4 = i * 4
            callback(v1, v2, v3, v4)
        }
        
        let endTime = CACurrentMediaTime()
        
        print("ObserveLatest Primitive swift sum: \(sumFromCallback)")
        
        return endTime - startTime
    }

    
    @objc class func runCombineTest_ObserveLatest(iterations: Int) -> TimeInterval {
        
        let startTime = Date()
        
        var sumFromCallback = 0
        
        let testObject = TestObjectSwift4()
        let publisher1 = testObject.publisher(for: \.value1)
        let publisher2 = testObject.publisher(for: \.value2)
        let publisher3 = testObject.publisher(for: \.value3)
        let publisher4 = testObject.publisher(for: \.value4)
        
        let combinedPublisher = Publishers.CombineLatest4(
            publisher1,
            publisher2,
            publisher3,
            publisher4
        )
        let cancellable = combinedPublisher.sink { value1, value2, value3, value4 in
            sumFromCallback += value1 + value2 + value3 + value4
            if (value1 + value2 + value3 + value4) % 2 == 0 {
                sumFromCallback <<= 8
            }
        }
        
        for i in 1..<iterations {
            testObject.value1 = i
            testObject.value2 = i * 2
            testObject.value3 = i * 3
            testObject.value4 = i * 4
            
        }
        
        let endTime = Date()
        
        print("ObserveLatest Combine sum: \(sumFromCallback)")
        
        return endTime.timeIntervalSince(startTime)
    }
}
