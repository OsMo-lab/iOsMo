//
//  CoordinatesSender.swift
//  iOsmo
//
//  Created by Olga Grineva on 15/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2016 Alexey Sirotkin. All rights reserved.
//

//used lib from https://mikeash.com/pyblog/friday-qa-2015-01-23-lets-build-swift-notifications.html

import Foundation
open class SendingManager: NSObject{
    //used lib
    let sentObservers = ObserverSet<LocationModel>()
    
    fileprivate let connectionManager = ConnectionManager.sharedConnectionManager
    open let locationTracker = LocationTracker()
    fileprivate let log = LogQueue.sharedLogQueue
    
    fileprivate var lcSendTimer: Timer?
    let aSelector : Selector = #selector(SendingManager.sending)
    fileprivate var onConnectionRun: ObserverSetEntry<(Bool, String)>?
    fileprivate var onSessionRun: ObserverSetEntry<(Bool, String)>?
    
    class var sharedSendingManager: SendingManager {
        struct Static {
            static let instance: SendingManager = SendingManager()
        }
        
        return Static.instance
    }
    
    override init(){
        
        super.init()
    }

    open func startSendingCoordinates(){
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
    
    open func pauseSendingCoordinates(){
        
        locationTracker.turnMonitoringOff()
        
        self.lcSendTimer?.invalidate()
        self.lcSendTimer = nil
        
    }
    
    open func stopSendingCoordinates(){
        
        pauseSendingCoordinates()
        connectionManager.closeSession()
    
    }
    
    open func sending(){
        //MUST REFACTOR
        if connectionManager.sessionOpened && connectionManager.connected {
            
            let coors: [LocationModel] = locationTracker.getLastLocations()
            print("CoordinateManager: got \(coors.count) coordinates")
            log.enqueue("CoordinateManager: got \(coors.count) coordinates")
            
            if coors.count > 0 {
           
                log.enqueue("CoordinateManager: sending \(coors.count) coordinates")
                self.connectionManager.sendCoordinates(Array<LocationModel>(arrayLiteral: coors.last!))
                
                for c in coors {
                    //notify about all - because it draw on map
                    self.sentObservers.notify(c)
                }
           }
        }
        
    }
    
    fileprivate func startSending(){
        if connectionManager.sessionOpened {
            
            log.enqueue("CoordinateManager: start Sending")
            self.lcSendTimer?.invalidate()
            self.lcSendTimer = nil
            var sendTime:TimeInterval = 5.0;
            if let sT = SettingsManager.getKey(SettingKeys.sendTime) {
                sendTime  = sT.doubleValue
                if sendTime < 1 {
                    sendTime = 5;
                }
            
            }

            
            self.lcSendTimer = Timer.scheduledTimer(timeInterval: sendTime, target: self, selector: aSelector, userInfo: nil, repeats: true)
           
       
        }
    }
     
}
