//
//  ObserverSet.swift
//  ObserverSet
//
//  Created by Mike Ash on 1/22/15.
//  Copyright (c) 2015 Mike Ash. All rights reserved.
//

import Dispatch


open class ObserverSetEntry<Parameters> {
    fileprivate weak var object: AnyObject?
    fileprivate let f: (AnyObject) -> (Parameters) -> Void
    
    fileprivate init(object: AnyObject, f: @escaping (AnyObject) -> (Parameters) -> Void) {
        self.object = object
        self.f = f
    }
}


open class ObserverSet<Parameters>: CustomStringConvertible {
    // Locking support
    
    fileprivate var queue = DispatchQueue(label: "com.iOsmo.ObserverSet", attributes: [])
    
    fileprivate func synchronized(_ f: () -> Void) {
        queue.sync(execute: f)
    }
    
    
    // Main implementation
    
    fileprivate var entries: [ObserverSetEntry<Parameters>] = []
    
    public init() {}
    
    open func add<T: AnyObject>(_ object: T, _ f: @escaping (T) -> (Parameters) -> Void) -> ObserverSetEntry<Parameters> {
        let entry = ObserverSetEntry<Parameters>(object: object, f: { f($0 as! T) })
        synchronized {
            self.entries.append(entry)
        }
        return entry
    }
    
    open func add(_ f: @escaping (Parameters) -> Void) -> ObserverSetEntry<Parameters> {
        return self.add(self, { ignored in f })
    }
    
    open func remove(_ entry: ObserverSetEntry<Parameters>) {
        synchronized {
            self.entries = self.entries.filter{ $0 !== entry }
        }
    }
    
    open func notify(_ parameters: Parameters) {
        var toCall: [(Parameters) -> Void] = []
        
        synchronized {
            for entry in self.entries {
                if let object: AnyObject = entry.object {
                    toCall.append(entry.f(object))
                }
            }
            self.entries = self.entries.filter{ $0.object != nil }
        }
        
        for f in toCall {
            f(parameters)
        }
    }
    
    
    // Printable
    
    open var description: String {
        var entries: [ObserverSetEntry<Parameters>] = []
        synchronized {
            entries = self.entries
        }
        
        let strings = entries.map{
            entry in
            (entry.object === self
                ? "\(entry.f)"
                : "\(entry.object! ) \(entry.f)")
        }
        let joined = strings.joined(separator: ", ")
        let aMirror = Mirror(reflecting:self);
        
        return "\(aMirror.description): (\(joined))"

    }
}

