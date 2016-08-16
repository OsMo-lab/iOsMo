//
//  SessionTimer.swift
//  iOsmo
//
//  Created by Olga Grineva on 01/04/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
public class SessionTimer: NSObject{
    
    public var IsStarted: Bool { get { return self.isStarted} }
    public var handler: (Int) -> Void
    
    private var isStarted : Bool = false
    private var timer = NSTimer()
    private var elapsedTime: Int = 0
    
    
    init(handler: (Int) -> Void){
    
        self.handler = handler
    }
    
    func start(){
    
        self.timer = NSTimer.scheduledTimerWithTimeInterval(1.0, target: self, selector: #selector(SessionTimer.tick), userInfo: nil, repeats: true)

        self.isStarted = true
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
