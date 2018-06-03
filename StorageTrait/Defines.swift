//
//  Defines.swift
//  StorageTrait
//
//  Created by Adrian C. Johnson on 5/31/18.
//  Copyright © 2018 CrossVision. All rights reserved.
//

import Foundation

// MARK: - Global Queues
public let globalBackgroundQueue: DispatchQueue = {
    let q = DispatchQueue.global(qos: DispatchQoS.QoSClass.background)
    q.setSpecific(key: syncKey, value: UUID())
    
    return q
}()

public let globalMainQueue: DispatchQueue = {
    let q = DispatchQueue.main
    q.setSpecific(key: syncKey, value: UUID())
    
    return q
}()

// MARK: - Dispatch
public let syncKey = DispatchSpecificKey<UUID>()

public func async(_ queue: DispatchQueue = globalMainQueue, barrier: Bool = false, delay: Double? = nil, closure: @escaping () -> Void) {
    if let d = delay {
        queue.asyncAfter(deadline: .now() + d, execute: closure)
    }
    else if barrier {
        queue.async(flags: .barrier, execute: closure)
    }
    else {
        queue.async(execute: closure)
    }
}
