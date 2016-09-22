//
//  CoordinatesSender.swift
//  iOsmo
//
//  Created by Olga Grineva on 15/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2016 Alexey Sirotkin. All rights reserved.
//

//used lib from https://mikeash.com/pyblog/friday-qa-2015-01-23-lets-build-swift-notifications.html

import Foundation
public class SendingManager: NSObject{
    //used lib
    let sentObservers = ObserverSet<LocationModel>()
    
    private let connectionManager = ConnectionManager.sharedConnectionManager
    public let locationTracker = LocationTracker()
    private let log = LogQueue.sharedLogQueue
    
    private let sendTime = 5.0 // seconds, should be imported from settings
    private var lcSendTimer: NSTimer?
    let aSelector : Selector = #selector(SendingManager.sending)
    private var onConnectionRun: ObserverSetEntry<(Bool, String)>?
    private var onSessionRun: ObserverSetEntry<(Bool, String)>?
    
    class var sharedSendingManager: SendingManager {
        struct Static {
            static let instance: SendingManager = SendingManager()
        }
        
        return Static.instance
    }
    
    override init(){
        
        super.init()
    }

    public func startSendingCoordinates(){
        
        locationTracker.turnMonitorinOn() //start getting coordinates

        if !connectionManager.connected {
            
            self.onConnectionRun = connectionManager.connectionRun.add{
                if $0.0 {
                    
                    self.onSessionRun = self.connectionManager.sessionRun.add{
                        if $0.0 {self.startSending()}
                        
                    }
                    self.connectionManager.openSession()
                }
                
                // unsubscribe because it is single event
                if let onConRun = self.onConnectionRun {
                    self.connectionManager.connectionRun.remove(onConRun)
                }
            }
            connectionManager.connect()
        }
        else if !connectionManager.sessionOpened {
            
            self.onSessionRun = self.connectionManager.sessionRun.add{
                if $0.0 {self.startSending()}
                else {
                    //unsibscribe when stop monitoring
                    if let onSesRun = self.onSessionRun {
                        self.connectionManager.sessionRun.remove(onSesRun)
                    }
                }
            }
            self.connectionManager.openSession()
        }
        else {startSending()}
        
        
    }
    
    public func pauseSendingCoordinates(){
        
        locationTracker.turnMonitoringOff()
        
        self.lcSendTimer?.invalidate()
        self.lcSendTimer = nil
        
    }
    
    public func stopSendingCoordinates(){
        
        pauseSendingCoordinates()
        connectionManager.closeSession()
    
    }
    
    public func sending(){
        
        //MUST REFACTOR
        if connectionManager.sessionOpened && connectionManager.connected {
            
            let coors: [LocationModel] = locationTracker.getLastLocations()
            print("CoordinateManager: got \(coors.count) coordinates")
            log.enqueue("CoordinateManager: drawing \(coors.count) coordinates")
            
            if coors.count > 0 {
           
                log.enqueue("CoordinateManager: drawing \(coors.count) coordinates")
                self.connectionManager.sendCoordinates(Array<LocationModel>(arrayLiteral: coors.last!))
                
                for c in coors {
                    //notify about all - because it draw on map
                    self.sentObservers.notify(c)
                }
           }
        }
        
    }
    
    private func startSending(){
        if connectionManager.sessionOpened {
            
            log.enqueue("CoordinateManager: start Sending")
            self.lcSendTimer?.invalidate()
            self.lcSendTimer = nil
            self.lcSendTimer = NSTimer.scheduledTimerWithTimeInterval(sendTime, target: self, selector: aSelector, userInfo: nil, repeats: true)
           
       
        }
    }
     
}
