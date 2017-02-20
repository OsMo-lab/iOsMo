//
//  SessionTimer.swift
//  iOsmo
//
//  Created by Olga Grineva on 01/04/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
open class SessionTimer: NSObject{
    
    open var IsStarted: Bool { get { return self.isStarted} }
    open var handler: (Int) -> Void
    
    fileprivate var isStarted : Bool = false
    fileprivate var timer = Timer()
    fileprivate var elapsedTime: Int = 0
    
    
    init(handler: @escaping (Int) -> Void){
    
        self.handler = handler
    }
    
    func start(){
        if (!self.isStarted) {
            self.timer = Timer.scheduledTimer(timeInterval: 1.0, target: self, selector: #selector(SessionTimer.tick), userInfo: nil, repeats: true)
            self.isStarted = true
        }
    }
    
    func reset(){
    
        self.elapsedTime = 0
    }
    
    func stop () {
        
        self.timer.invalidate()
        self.isStarted = false
    }
    
    func tick() {
    
        self.elapsedTime += 1
        
        handler(elapsedTime)
    }
    
    
    deinit{
        self.timer.invalidate()
    }
}
