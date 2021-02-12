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
    
    var onLocationUpdated : ObserverSetEntry<(LocationModel)>?
    
    fileprivate var lcSendTimer: Timer?
    let aSelector : Selector = #selector(SendingManager.sending)
    fileprivate var onConnectionRun: ObserverSetEntry<(Int, String)>?
    fileprivate var onSessionRun: ObserverSetEntry<(Int, String)>?
    let sessionStarted = ObserverSet<(Int)>()
    let sessionPaused = ObserverSet<(Int)>()
    var lastLocations = [LocationModel]()

    
    class var sharedSendingManager: SendingManager {
        struct Static {
            static let instance: SendingManager = SendingManager()
        }
        
        return Static.instance
    }
 
    override init(){
        
        super.init()
        
        self.onLocationUpdated = locationTracker.locationUpdated.add {
            self.log.enqueue("SendingManager: onLocationUpdated")
            if self.connectionManager.isGettingLocation  {
                self.connectionManager.sendCoordinate($0)
                self.connectionManager.isGettingLocation = false
            } else {
                if self.connectionManager.sessionOpened {
                    self.connectionManager.sendCoordinates([$0])
                }
                self.sentObservers.notify($0)
            }
        }

    }


    open func startSendingCoordinates(_ once: Bool){
        locationTracker.turnMonitorinOn(once: once) //start getting coordinates
        if (once) {
            return
        }

        if !connectionManager.connected {
            self.onConnectionRun = connectionManager.connectionRun.add{
                if $0.0 == 0{
                    self.onSessionRun = self.connectionManager.sessionRun.add{
                        if $0.0 == 0{
                            self.startSending()
                        }
                    }
                    self.connectionManager.openSession()
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
                } else {
                    //unsibscribe when stop monitoring
                    if let onSesRun = self.onSessionRun {
                        self.connectionManager.sessionRun.remove(onSesRun)
                    }
                }
            }
            self.connectionManager.openSession()
        } else {
            startSending()
        }
    }
    
    open func pauseSendingCoordinates(){
        locationTracker.turnMonitoringOff()
        
        //self.lcSendTimer?.invalidate()
        //self.lcSendTimer = nil
        sessionPaused.notify((0))
        UIApplication.shared.isIdleTimerDisabled = false
        
    }
    
    open func stopSendingCoordinates(){
        pauseSendingCoordinates()
        connectionManager.closeSession()
    }
    
    @objc open func sending(){
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
                
           }
        }
    }
    
    fileprivate func startSending(){
        if (connectionManager.sessionOpened || connectionManager.isGettingLocation) {
            
            log.enqueue("Sending Manager: start Sending")
            //self.lcSendTimer?.invalidate()
            //self.lcSendTimer = nil
            
            //self.lcSendTimer = Timer.scheduledTimer(timeInterval: 0, target: self, selector: aSelector, userInfo: nil, repeats: true)
            if connectionManager.sessionOpened {
                sessionStarted.notify((0))
            }
            
            UIApplication.shared.isIdleTimerDisabled = SettingsManager.getKey(SettingKeys.isStayAwake)!.boolValue
            
        }
    }
     
}
