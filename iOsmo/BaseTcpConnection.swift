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

    open var addCallBackOnError: ((Bool) -> Void)? {
        get {
            return tcpClient.callbackOnError
        } set {
            tcpClient.callbackOnError = newValue
        }
    }
    
    open var addCallBackOnSendStart: (() -> Void)? {
        get {
            return tcpClient.callbackOnSendStart
        } set {
            tcpClient.callbackOnSendStart = newValue
        }
    }
    
    open var addCallBackOnSendEnd: (() -> Void)? {
        get {
            return tcpClient.callbackOnSendEnd
        } set {
            tcpClient.callbackOnSendEnd = newValue
        }
    }
    
    open var addCallBackOnConnect: (() -> Void)? {
        get {
            return tcpClient.callbackOnConnect
        } set {
            tcpClient.callbackOnConnect = newValue
        }
    }
    
    open var addCallBackOnCloseConnection: (() -> Void)? {
        get {
            return tcpClient.callbackOnCloseConnection
        } set {
            tcpClient.callbackOnCloseConnection = newValue
        }
    }
    
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
    
    //var connected: Bool = false
    var sessionOpened: Bool = false

  
    func onSentCoordinate(cnt: Int){
        log.enqueue("Removing \(cnt) coordinates from buffer")
        for _ in 1...cnt {
            if self.coordinates.count > 0 {
                self.coordinates.remove(at: 0)
            }
        }
        
        sendNextCoordinates()
    }
    
    
    
    open func closeConnection(){
        tcpClient.closeConnection()
    }

    open func closeSession(){
        let request = "\(Tags.closeSession.rawValue)"
        closeSession(request)
    }

    
    //TODO: should be in sending manager!!!
    fileprivate func sendNextCoordinates(){
        /*
         if self.shouldCloseSession {
            
            self.coordinates.removeAll(keepingCapacity: false)
            closeSession()
        }*/
        
        //TODO: refactoring send best coordinates
        let cnt = self.coordinates.count;
        if self.sessionOpened && cnt > 0 {
            var req = ""
            var sep = ""
            var idx = 0;
            if cnt > 1 {
                sep = "\""
            }
            for theCoordinate in self.coordinates {
                if req != "" {
                    req = "\(req),"
                }
                req = "\(req)\(sep)\(theCoordinate.getCoordinateRequest)\(sep)"
                idx = idx + 1
                //Ограничиваем количество отправляемых точек в одном пакете
                if idx > 500 {
                    break;
                }
            }
            if cnt > 1 {
                req = "\(Tags.buffer.rawValue)|[\(req)]"
            } else {
                req = "\(Tags.coordinate.rawValue)|\(req)"
            }
            send(req)
        }
    }
    
    
    
    func closeSession(_ request: String){
        tcpClient.send(message: request)
    }
    
    open func send(_ request: String){
        tcpClient.send(message: request)
    }
    
    
    
    
}
