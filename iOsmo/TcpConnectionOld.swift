///Users/olame/Code/iOsmoSwift/iOsmo/iOsmo/TcpConnection.swift
//  TcpConnection.swift
//  iOsmo
//
//  Created by Olga Grineva on 13/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

//TODO: modify notification model

//may be useful https://github.com/DerLobi/RedisClient/blob/master/RedisClient/RedisConnection.swift


import Foundation
public class TcpConnectionOld : BaseTcpConnection, ConnectionProtocol {

    public func getSessionUrl() -> String? {return "https://osmo.mobi/u/\(sessionUrlParsed)"}

    
    public var sessionUrlParsed: String = ""
  
    public override func connect(token: Token){
        
        super.connect(token)
        super.tcpClient.callbackOnParse = parseOutput
        sendToken(token)
    }
    
    
    public func openSession(){
    
        let request = "\(TagsOld.openSession.rawValue)"
        super.send(request)
    }
    
    
    public func closeSession(){
    
        log.enqueue("send close session request")
        let request = "\(TagsOld.closeSession.rawValue)"
        super.closeSession(request)
    }
    
    private func sendToken(token: Token){
        
        let request = "\(TagsOld.token.rawValue)\(token.token)"
        
        super.send(request)
        log.enqueue("send token")
    }
    
    //probably should be refactored and moved to ReconnectManager
    private func sendPing(){
        
        super.send("\(TagsOld.pong.rawValue)")
        log.enqueue("SendPing: \(TagsOld.pong.rawValue)")
    }
    
    
    private func parseOutput(output: String){
        
        let outputContains = {(tag: TagsOld) -> Bool in return output.rangeOfString(tag.rawValue) != nil}
        
        if outputContains(TagsOld.token){
            
            super.changeState(NSNumber(bool: true), key: UpdatesEnum.OpenConnection.rawValue)
            //self.setValue(NSNumber(bool: true), forKey: UpdatesEnum.OpenConnection.rawValue)
            
        }
        
        if outputContains(TagsOld.openSession){
            
            print("open session")
            log.enqueue("session opened answer")
            
            sessionUrlParsed = parseTag(output, key: KeysOld.sessionUrl)!
            
            super.changeState(NSNumber(bool: true), key: UpdatesEnum.SessionStarted.rawValue)
            //self.setValue(NSNumber(bool: true), forKey: UpdatesEnum.SessionStarted.rawValue)
            
        }
        
        if outputContains(TagsOld.closeSession){
            
            print("session closed")
            log.enqueue("session closed answer")
            
            super.changeState(NSNumber(bool: false), key: UpdatesEnum.SessionStarted.rawValue)
            //self.setValue(NSNumber(bool: false), forKey: UpdatesEnum.SessionStarted.rawValue)
            //should update status of session
        }
        
        if outputContains(TagsOld.kick){
            
            print("connection kicked")
            log.enqueue("connection kicked")
            
            //should update status of session and connection
        }
        
        if outputContains(TagsOld.remotePP){
            
            print("server wants answer :)")
            log.enqueue("server wants answer ;)")
            sendPing()
        }
        if outputContains(TagsOld.coordinate) {
           super.onSentCoordinate()
        }
        
        
    }
    
   
}