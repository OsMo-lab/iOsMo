//
//  LogQueue.swift
//  iOsmo
//
//  Created by Olga Grineva on 20/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import Foundation

public class LogQueue {
    var innerQueue: [String]
    let maxSize = 500
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
    
    func enqueue(record: String){
        let dateFormat = NSDateFormatter()
        dateFormat.dateFormat = "HH:mm:ss"
        let eventDate = dateFormat.stringFromDate(NSDate())
        let event = "\(eventDate): \(record)"
        if innerQueue.count >= maxSize {
            
            innerQueue.removeAtIndex(0)
        }
        innerQueue.append(event)
    }
    
    func getArray(startIndex: Int, count: Int) -> [String] {
        
        var result = [String]()
        for index in startIndex...startIndex + count - 1 {
            result.append(innerQueue[index])
        }
    
        return result
    }
    
}