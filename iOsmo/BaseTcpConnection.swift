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
    let answerObservers = ObserverSet<(String)>()
    
    let tcpClient = TcpClient()

    open func parseOutput(_ output: String){
        answerObservers.notify(output)
    }
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
    
    override init(){
        super.init()
    }
    
    func connect(_ token: Token){
        tcpClient.callbackOnParse = parseOutput
        tcpClient.createConnection(token)
    }

    open func closeConnection(){
        tcpClient.closeConnection()
    }

    open func send(_ request: String){
        tcpClient.send(message: request)
    }
    
    
    
    
}
