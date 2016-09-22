//
//  BaseTcpConnection.swift
//  iOsmo
//
//  Created by Olga Grineva on 24/03/15.
//  Copyright (c) 2015 Olga Grineva, (c) 2016 Alexey Sirotkin All rights reserved.
//

import Foundation
import UIKit

open class BaseTcpConnection: NSObject {
    
    let tcpClient = TcpClient()

    open var addCallBackOnError: ((Bool) -> Void)? { get {return tcpClient.callbackOnError} set { tcpClient.callbackOnError = newValue } }
    
    open var shouldCloseSession = false
    
    let log = LogQueue.sharedLogQueue
   
    var coordinates: [LocationModel]
    
    override init(){
        
        coordinates = [LocationModel]()
        super.init()
        
    }
    
    func connect(_ token: Token){
        
        tcpClient.createConnection(token)
    }
    
   
    open func sendCoordinates(_ coordinates: [LocationModel]){
        
        self.coordinates += coordinates
        sendNextCoordinates()
    }
    
    //properties
    
    var connected: Bool = false
    var sessionOpened: Bool = false

    
    func onSentCoordinate(){
    
        if self.coordinates.count > 0 {
            self.coordinates.remove(at: 0)
        }
        sendNextCoordinates()
    }
    
    open func sendSystemInfo(){
        let model = UIDevice.current.model
        let version = UIDevice.current.systemVersion
        
        let jsonInfo: NSDictionary =
            ["devicename": model, "version": "iOS \(version)"]
        
        do{
            let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
            
            if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.TRACKER_SYSTEM_INFO.rawValue)|\(jsonString)"
                send(request)            }
        }catch {
            
            print("error generating system info")
        }
    }
    
    open func sendBatteryStatus(){
        UIDevice.current.isBatteryMonitoringEnabled = true
        let level = UIDevice.current.batteryLevel * 100
        var state = -1;
        if (UIDevice.current.batteryState == .charging) {
            state = 1;
        }
        
        let jsonInfo: NSDictionary =
            ["percent": level, "plugged": state]
        
        do{
            let data = try JSONSerialization.data(withJSONObject: jsonInfo, options: JSONSerialization.WritingOptions(rawValue: 0))
            
            if let jsonString = NSString(data: data, encoding: String.Encoding.utf8.rawValue) {
                let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.TRACKER_BATTERY_INFO.rawValue)|\(jsonString)"
                send(request)            }
        }catch {
            
            print("error generating battery info")
        }
    }
    
    open func closeSession(){
        
        log.enqueue("send close session request")
        let request = "\(Tags.closeSession.rawValue)"
        closeSession(request)
    }

    
    //TODO: should be in sending manager!!!
    fileprivate func sendNextCoordinates(){
        if self.shouldCloseSession {
            
            self.coordinates.removeAll(keepingCapacity: false)
            closeSession()
            
        }
        
        //TODO: refactoring send best coordinates
        if self.sessionOpened && self.coordinates.count > 0 {
            
            if let theCoordinate = self.coordinates.first {
                
                send(theCoordinate.getCoordinateRequest)
            }
        }
    }
    
    
    
    func closeSession(_ request: String){
        
        log.enqueue("should close session: \(shouldCloseSession)")
        self.shouldCloseSession = self.coordinates.count == 0
        
        if self.shouldCloseSession   {
           tcpClient.send(request)
        }
        
        shouldCloseSession = !shouldCloseSession
        
    }
    
    open func send(_ request: String){
        
        tcpClient.send(request)
    }
    
    
    
    
}
