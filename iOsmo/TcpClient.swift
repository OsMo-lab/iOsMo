//
//  TcpClient.swift
//  iOsmo
//
//  Created by Olga Grineva on 25/03/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation

public class TcpClient : NSObject, NSStreamDelegate {

    let log = LogQueue.sharedLogQueue
    var inputStream: NSInputStream?
    var outputStream: NSOutputStream?
    // MARK: - NSStreamDelegate
    public var callbackOnParse: ((String) -> Void)?
    public var callbackOnError: ((Bool) -> Void)?
    
    public func createConnection(token: Token){
        
        //different creation for different ios
        
        
        let aSelector : Selector = #selector(NSProcessInfo.isOperatingSystemAtLeastVersion(_:))
        let higher8 = NSProcessInfo.instancesRespondToSelector(aSelector)
        
        if higher8 {
        
            NSStream.getStreamsToHostWithName("osmo.mobi", port: token.port, inputStream: &inputStream, outputStream: &outputStream)
            
        }
        else {
            var inStreamUnmanaged:Unmanaged<CFReadStream>?
            var outStreamUnmanaged:Unmanaged<CFWriteStream>?
            CFStreamCreatePairWithSocketToHost(nil, "osmo.mobi", UInt32(token.port), &inStreamUnmanaged, &outStreamUnmanaged)
            inputStream = inStreamUnmanaged?.takeRetainedValue()
            outputStream = outStreamUnmanaged?.takeRetainedValue()
            
        }
        inputStream!.setProperty(NSStreamSocketSecurityLevelTLSv1, forKey: NSStreamSocketSecurityLevelKey)
        outputStream!.setProperty(NSStreamSocketSecurityLevelTLSv1, forKey: NSStreamSocketSecurityLevelKey)
        if let inputStream = self.inputStream {
            
            inputStream.delegate = self
            inputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
            inputStream.open()
        }
        
        if let outputStream = self.outputStream {
            outputStream.delegate = self
            outputStream.scheduleInRunLoop(NSRunLoop.currentRunLoop(), forMode: NSDefaultRunLoopMode)
            outputStream.open()
        }
        
        log.enqueue("create connection, input and output streams")
    }
    
    public func send(request: String){
        
        log.enqueue("r: \(request)")
        print("r: \(request)")
        let requestToSend = "\(request)\n"
        if let outputStream = outputStream, data = requestToSend.dataUsingEncoding(NSUTF8StringEncoding) {
             outputStream.write(UnsafePointer<UInt8>(data.bytes), maxLength: data.length)
        }
        else {
            log.enqueue("error: send request")
            print("error: send request")
        }
    }

    
    private var message: String = ""
    
    public func stream(aStream: NSStream, handleEvent eventCode: NSStreamEvent) {
        //print(aStream.description, eventCode)
        switch (eventCode) {
            
        case NSStreamEvent.None:
            print ("None")

   
        case NSStreamEvent.EndEncountered:
            print ("EndEncountered")
            return
        
        
        case NSStreamEvent.OpenCompleted:
            
            print("stream opened")
            log.enqueue("stream opened")
        case NSStreamEvent.ErrorOccurred:
            
            print("stream was handle error, connection is out")
            log.enqueue("stream was handle error, connection is out")
            if callbackOnError != nil {
                
                callbackOnError!(true)
            }
        case NSStreamEvent.HasSpaceAvailable:
            print("HasSpaceAvailable")
            break
        case NSStreamEvent.HasBytesAvailable:
            print("HasBytesAvailable")
            
            let bufferSize = 1024
            var buffer = [UInt8](count: bufferSize, repeatedValue: 0)
            var len: Int = 0
            
            if let iStream = inputStream {
               
                while(iStream.hasBytesAvailable)
                {
                    len = iStream.read(&buffer, maxLength: bufferSize)
                    if len > 0 {
                        
                        if let output = NSString(bytes: &buffer, length: len, encoding: NSUTF8StringEncoding) {
                            message = "\(message)\(output)"
                        }
                    }
                }
            }
            else {
                print("Stream is empty")
                log.enqueue("Stream is empty")
                
                return
            }
           
            //insert check
            print(message)
            if !message.isEmpty {
                
                //check for spliting:
                let responceSplit = message.componentsSeparatedByString("\n")
                var count = 0
                for res in responceSplit {
                    if !res.isEmpty{
                        
                        let subst = message[Range(message.endIndex.advancedBy(-1)..<message.endIndex)]
                        if responceSplit.count < 2 && subst != "\n"{
                            return
                        }
                        else
                        {
                            //print what we parse
                            print("a: \(res)")
                            log.enqueue("a: \(res)")
                            
                            if let call = self.callbackOnParse {
                                    call(res)
                            }
                            
                        }
                        let resAdvance = res + "\n"
                        message = (responceSplit.count != count) ? message.substringWithRange(Range<String.Index>(resAdvance.endIndex..<message.endIndex)) : res
                        
                        count += 1
                    }
                    
                }
                
            }
            
        default:
            print(eventCode)
            log.enqueue("\(eventCode)")
            print("Some unhandled event was occured in stream")
            log.enqueue("Some unhandled event was occured in stream")
        }
        
    }
}
