//
//  CoordinatesSender.swift
//  iOsmo
//
//  Created by Olga Grineva on 15/12/14.
//  Copyright (c) 2014 Olga Grineva, (c) 2016 Alexey Sirotkin. All rights reserved.
//

//used lib from https://mikeash.com/pyblog/friday-qa-2015-01-23-lets-build-swift-notifications.html

import Foundation
import UIKit

open class SendingManager: NSObject{
    //used lib
    let sentObservers = ObserverSet<LocationModel>()
    
    fileprivate let connectionManager = ConnectionManager.sharedConnectionManager
    public let locationTracker = LocationTracker()
    fileprivate let log = LogQueue.sharedLogQueue
    
    fileprivate var lcSendTimer: Timer?
    let aSelector : Selector = #selector(SendingManager.sending)
    fileprivate var onConnectionRun: ObserverSetEntry<(Int, String)>?
    fileprivate var onSessionRun: ObserverSetEntry<(Int, String)>?
    let sessionStarted = ObserverSet<(Int)>()
    let sessionPaused = ObserverSet<(Int)>()

    
    class var sharedSendingManager: SendingManager {
        struct Static {
            static let instance: SendingManager = SendingManager()
        }
        
        return Static.instance
    }
    
    override init(){
        
        super.init()
    }

    open func sendSystemInfo(){
        if !connectionManager.connected {
            self.onConnectionRun = connectionManager.connectionRun.add{
                if $0.0 == 0 {
                    self.connectionManager.sendSystemInfo()
                }
                
                // unsubscribe because it is single event
                if let onConRun = self.onConnectionRun {
                    self.connectionManager.connectionRun.remove(onConRun)
                }
            }
            connectionManager.connect()
        }else{
            self.connectionManager.sendSystemInfo()
        }
    }
    
    open func sendBatteryStatus(_ rc: String){
        if !connectionManager.connected {
            self.onConnectionRun = connectionManager.connectionRun.add{
                if $0.0 == 0 {
                    self.connectionManager.sendBatteryStatus()
                }

                // unsubscribe because it is single event
                if let onConRun = self.onConnectionRun {
                    self.connectionManager.connectionRun.remove(onConRun)
                }
            }
            connectionManager.connect()
        }else{
            self.connectionManager.sendBatteryStatus()
        }
    }
    
    open func startSendingCoordinates(_ rc: String){
        let once = (!connectionManager.sessionOpened && rc == RemoteCommand.WHERE.rawValue) ? true : false;
        locationTracker.turnMonitorinOn(once: once) //start getting coordinates

        if !connectionManager.connected {
            self.onConnectionRun = connectionManager.connectionRun.add{
                if $0.0 == 0{
                    self.onSessionRun = self.connectionManager.sessionRun.add{
                        if $0.0 == 0{
                            self.startSending()
                            if (rc != "" /*&& rc != RemoteCommand.WHERE.rawValue*/) {
                                self.connectionManager.sendRemoteCommandResponse(rc)
                            }
                        }
                    }
                    if rc != RemoteCommand.WHERE.rawValue {
                        self.connectionManager.openSession()
                    }else{
                        self.startSending()
                    }
                    
                }
                
                // unsubscribe because it is single event
                if let onConRun = self.onConnectionRun {
                    self.connectionManager.connectionRun.remove(onConRun)
                }
            }
            connectionManager.connect()
        } else if !connectionManager.sessionOpened {
            self.onSessionRun = self.connectionManager.sessionRun.add{
                if ($0.0 == 0){
                    self.startSending()
                    if (rc != "" && rc != RemoteCommand.WHERE.rawValue){
                        self.connectionManager.sendRemoteCommandResponse(rc)
                    }
                } else {
                    //unsibscribe when stop monitoring
                    if let onSesRun = self.onSessionRun {
                        self.connectionManager.sessionRun.remove(onSesRun)
                    }
                }
            }
            if rc != RemoteCommand.WHERE.rawValue {
                self.connectionManager.openSession()
            }else{
                self.startSending()
            }
        } else {
            startSending()
            if (rc != "" && rc != RemoteCommand.WHERE.rawValue) {
                self.connectionManager.sendRemoteCommandResponse(rc)
            }
        }
    }
    
    open func pauseSendingCoordinates(_ rc: String){
        locationTracker.turnMonitoringOff()
        
        self.lcSendTimer?.invalidate()
        self.lcSendTimer = nil
        sessionPaused.notify((0))
        UIApplication.shared.isIdleTimerDisabled = false
        if (rc != "" && rc != RemoteCommand.WHERE.rawValue){
            self.connectionManager.sendRemoteCommandResponse(rc)
        }

    }
    
    open func stopSendingCoordinates(_ rc: String){
        pauseSendingCoordinates(rc)
        connectionManager.closeSession()
    }
    
    open func sending(){
        //MUST REFACTOR
        if (connectionManager.sessionOpened || connectionManager.isGettingLocation)  && connectionManager.connected {
            let coors: [LocationModel] = locationTracker.getLastLocations()
            log.enqueue("SendingManager: got \(coors.count) coordinates")
            
            if coors.count > 0 {
                log.enqueue("SendingManager: sending \(coors.count) coordinates")
                if connectionManager.isGettingLocation {
                    self.connectionManager.sendCoordinate(coors[0])
                }
                if connectionManager.sessionOpened {
                    self.connectionManager.sendCoordinates(coors)
                }
                
                for c in coors {
                    //notify about all - because it draw on map
                    self.sentObservers.notify(c)
                }
                if (connectionManager.isGettingLocation && !connectionManager.sessionOpened) {
                    pauseSendingCoordinates("")
                    connectionManager.isGettingLocation = false
                }
           }
        }
    }
    
    fileprivate func startSending(){
        if (connectionManager.sessionOpened || connectionManager.isGettingLocation) {
            
            log.enqueue("Sending Manager: start Sending")
            self.lcSendTimer?.invalidate()
            self.lcSendTimer = nil
            var sendTime:TimeInterval = 4;
            if let sT = SettingsManager.getKey(SettingKeys.sendTime) {
                sendTime  = sT.doubleValue
                if sendTime < 4 {
                    sendTime = 4;
                }
            
            }
            self.lcSendTimer = Timer.scheduledTimer(timeInterval: sendTime, target: self, selector: aSelector, userInfo: nil, repeats: true)
            if connectionManager.sessionOpened {
                sessionStarted.notify((0))
            }
            
            UIApplication.shared.isIdleTimerDisabled = SettingsManager.getKey(SettingKeys.isStayAwake)!.boolValue
            
        }
    }
     
}
