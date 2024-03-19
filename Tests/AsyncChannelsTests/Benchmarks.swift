//
//  File.swift
//  
//
//  Created by Brian Floersch on 3/18/24.
//

import Foundation
import XCTest
@testable import AsyncChannels

final class Benchmarks: XCTestCase {
    
    func timeIt(iterations: Int, block: () async -> ()) async {
        
        var sum: CFAbsoluteTime = 0
        for _ in 0..<iterations {
            let startTime = CFAbsoluteTimeGetCurrent()
            await block()
            let timeElapsed = CFAbsoluteTimeGetCurrent() - startTime
            sum += timeElapsed
        }
        print("Time elapsed: \(sum / Double(iterations))")
        
    }
    
    func testSingleReaderManyWriter() async {
        await timeIt(iterations: 1) {
            let a = Channel<Int>()
            var sum = 0
            
            for _ in (0...100) {
                Task {
                    for _ in (0...10000) {
                        await a <- 1
                    }
                }
            }
            
            while sum < 1_000_000 {
                sum += (await <-a)!
            }
        }
    }
    
    func testHighConcurrency() async {
        await timeIt(iterations: 3) {
            let a = Channel<Int>()
            var sum = 0
            
            for _ in (0...1000) {
                Task {
                    for _ in (0...1000) {
                        await a <- 1
                    }
                }
            }
            
            while sum < 1_000_000 {
                sum += (await <-a)!
            }
        }
    }
    
    func testHighConcurrencyBuffered() async {
        await timeIt(iterations: 1) {
            let a = Channel<Int>(capacity: 20)
            var sum = 0
            
            for _ in (0...1000) {
                Task {
                    for _ in (0...1000) {
                        await a <- 1
                    }
                }
            }
            
            while sum < 1_000_000 {
                sum += (await <-a)!
            }
        }
    }
    
}
