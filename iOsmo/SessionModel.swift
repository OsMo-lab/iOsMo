//
//  SessionModel.swift
//  iOsmo
//
//  Created by Olga Grineva on 21/01/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
import Mapbox

public class SessionModel {

    private var startTime: NSDate?
    private var stopTime: NSDate?
    
    private var downTime: NSTimeInterval?
    
    private var elapsedTime: NSTimeInterval? {
        get{
            let diff = stopTime!.timeIntervalSinceDate(startTime!) - downTime!
            return diff
        }
    }
    
    private var distance: Double?
    
    private var speed: Double?
    private var avgSpeed: Double?
    private var maxSpeed: Double?
    
    private var status: SessionStatus?
    private var statusHistory: [SessionStatus]?
    
    private var name: String?
    
    private var rawPoints: [LocationModel]?
    
    private var route : [CLLocation]?
    
    
    
    public init() {
    }
    
    public func start(){
        
    }
    
    
    public func getRoute () -> NSData {
    
        return NSData()
    }
    
    public func stop(){}
    
    public func pause(){}
    
    public func save(){}
    
    public func load(){}
    
}







