//
//  ActorThing.swift
//  Benchmarks
//
//  Created by Brian Floersch on 3/22/24.
//

import Foundation

public actor Thing {
    private var val: Int?
    
    public init(val: Int? = nil) {
        self.val = val
    }
    
    public func set(_ v: Int) async {
        val = v
    }
    
    public func get() async -> Int? {
        return val
        
    }
}
