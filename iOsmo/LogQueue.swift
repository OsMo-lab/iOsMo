//
//  LogQueue.swift
//  iOsmo
//
//  Created by Olga Grineva on 20/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import Foundation

open class LogQueue {
    var innerQueue: [String]
    let maxSize = 5000
    class var sharedLogQueue : LogQueue {
        
        struct Static {
            static let instance: LogQueue = LogQueue()

        }
        
        return Static.instance
    }
    
    init() {
       
        innerQueue = [String]()
        
    }
    
    var count: Int{ get{ return innerQueue.count }}
    
    func enqueue(_ record: String){
        let dateFormat = DateFormatter()
        dateFormat.dateFormat = "HH:mm:ss"
        let eventDate = dateFormat.string(from: Date())
        let event = "\(eventDate): \(record)"
        if innerQueue.count >= maxSize {
            innerQueue.remove(at: 0)
        }
        innerQueue.append(event)
        print(record)
    }
    
    func getArray(_ startIndex: Int, count: Int) -> [String] {
        
        var result = [String]()
        if (count>0) {
            for index in startIndex...startIndex + count - 1 {
                result.append(innerQueue[index])
            }
        }
    
        return result
    }
    
}
