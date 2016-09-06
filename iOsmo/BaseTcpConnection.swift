//
//  BaseTcpConnection.swift
//  iOsmo
//
//  Created by Olga Grineva on 24/03/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation
public class BaseTcpConnection: NSObject {
    
    let tcpClient = TcpClient()

    public var addCallBackOnError: ((Bool) -> Void)? { get {return tcpClient.callbackOnError} set { tcpClient.callbackOnError = newValue } }
    
    public var shouldCloseSession = false
    
    let log = LogQueue.sharedLogQueue
   
    var coordinates: [LocationModel]
    
    override init(){
        
        coordinates = [LocationModel]()
        super.init()
        
    }
    
    func connect(token: Token){
        
        tcpClient.createConnection(token)
    }
    
   
    public func sendCoordinates(coordinates: [LocationModel]){
        
        self.coordinates += coordinates
        sendNextCoordinates()
    }
    
    //properties
    
    var connected: Bool = false
    var sessionOpened: Bool = false

    
    func onSentCoordinate(){
    
        if self.coordinates.count > 0 {
            self.coordinates.removeAtIndex(0)
        }
        sendNextCoordinates()
    }
    
    public func sendSystemInfo(){
        let model = UIDevice.currentDevice().model
        let version = UIDevice.currentDevice().systemVersion
        
        let jsonInfo: AnyObject =
            ["devicename": model, "version": "iOS \(version)"]
        
        do{
            let data = try NSJSONSerialization.dataWithJSONObject(jsonInfo, options: NSJSONWritingOptions(rawValue: 0))
            
            if let jsonString = NSString(data: data, encoding: NSUTF8StringEncoding) {
                let request = "\(Tags.remoteCommandResponse.rawValue)\(RemoteCommand.TRACKER_SYSTEM_INFO.rawValue)|\(jsonString)"
                send(request)            }
        }catch {
            
            print("error generating system info")
        }
        
        
    }
    
    public func closeSession(){
        
        log.enqueue("send close session request")
        let request = "\(Tags.closeSession.rawValue)"
        closeSession(request)
    }

    
    //TODO: should be in sending manager!!!
    private func sendNextCoordinates(){
        if self.shouldCloseSession {
            
            self.coordinates.removeAll(keepCapacity: false)
            closeSession()
            
        }
        
        //TODO: refactoring send best coordinates
        if self.sessionOpened && self.coordinates.count > 0 {
            
            if let theCoordinate = self.coordinates.first {
                
                send(theCoordinate.getCoordinateRequest)
            }
        }
    }
    
    
    
    func closeSession(request: String){
        
        log.enqueue("should close session: \(shouldCloseSession)")
        self.shouldCloseSession = self.coordinates.count == 0
        
        if self.shouldCloseSession   {
           tcpClient.send(request)
        }
        
        shouldCloseSession = !shouldCloseSession
        
    }
    
    public func send(request: String){
        
        tcpClient.send(request)
    }
    
    
    
    
}