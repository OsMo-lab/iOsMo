//
//  TcpClient.swift
//  iOsmo
//
//  Created by Olga Grineva on 25/03/15.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation

open class TcpClient : NSObject, StreamDelegate {

    let log = LogQueue.sharedLogQueue
    var inputStream: InputStream?
    var outputStream: OutputStream?
    // MARK: - NSStreamDelegate
    open var callbackOnParse: ((String) -> Void)?
    open var callbackOnError: ((Bool) -> Void)?
    
    open func createConnection(_ token: Token){
        if (token.port>0) {
            Stream.getStreamsToHost(withName: "osmo.mobi", port: token.port, inputStream: &inputStream, outputStream: &outputStream)
            if let inputStream = self.inputStream {

                inputStream.setProperty(StreamSocketSecurityLevel.tlSv1.rawValue, forKey: Stream.PropertyKey.socketSecurityLevelKey)
                
                inputStream.delegate = self
                inputStream.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                inputStream.open()
            }
            
            if let outputStream = self.outputStream {
                outputStream.setProperty(StreamSocketSecurityLevel.tlSv1.rawValue, forKey: Stream.PropertyKey.socketSecurityLevelKey)
                outputStream.delegate = self
                outputStream.schedule(in: RunLoop.current, forMode: RunLoopMode.defaultRunLoopMode)
                outputStream.open()
            }
            
            log.enqueue("create connection, input and output streams")
        }
    }
    
    open func send(_ request: String){
        
        log.enqueue("r: \(request)")
        print("r: \(request)")
        let requestToSend = "\(request)\n"
        if let outputStream = outputStream, let data = requestToSend.data(using: String.Encoding.utf8) {
             outputStream.write((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
        }
        else {
            log.enqueue("error: send request")
            print("error: send request")
        }
    }

    
    fileprivate var message: String = ""
    
    open func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        //print(aStream.description, eventCode)
        switch (eventCode) {
            
        case Stream.Event():
            print ("None")

   
        case Stream.Event.endEncountered:
            print ("EndEncountered")
            return
        
        
        case Stream.Event.openCompleted:
            
            print("stream opened")
            log.enqueue("stream opened")
        case Stream.Event.errorOccurred:
            
            print("stream was handle error, connection is out")
            log.enqueue("stream was handle error, connection is out")
            if callbackOnError != nil {
                
                callbackOnError!(true)
            }
        case Stream.Event.hasSpaceAvailable:
            print("HasSpaceAvailable")
            break
        case Stream.Event.hasBytesAvailable:
            print("HasBytesAvailable")
            
            let bufferSize = 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            var len: Int = 0
            
            if let iStream = inputStream {
               
                while(iStream.hasBytesAvailable)
                {
                    len = iStream.read(&buffer, maxLength: bufferSize)
                    if len > 0 {
                        
                        if let output = NSString(bytes: &buffer, length: len, encoding: String.Encoding.utf8.rawValue) {
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
                let responceSplit = message.components(separatedBy: "\n")
                var count = 0
                for res in responceSplit {
                    if !res.isEmpty{
                        
                        let subst = message[Range(message.characters.index(message.endIndex, offsetBy: -1)..<message.endIndex)]
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
                        message = (responceSplit.count != count) ? message.substring(with: Range<String.Index>(resAdvance.endIndex..<message.endIndex)) : res
                        
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
