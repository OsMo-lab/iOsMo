//
//  TcpClient.swift
//  iOsmo
//
//  Created by Olga Grineva on 25/03/15.
//  Copyright (c) 2014 Olga Grineva, (c) 2016 Alexey Sirotkin. All rights reserved.
//

import Foundation

open class TcpClient : NSObject, StreamDelegate {

    fileprivate let log = LogQueue.sharedLogQueue
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var _messagesQueue:Array<String> = [String]()
    open var callbackOnParse: ((String) -> Void)?
    open var callbackOnError: ((Bool) -> Void)?
    open var callbackOnSendStart: (() -> Void)?
    open var callbackOnSendEnd: (() -> Void)?
    open var callbackOnConnect: (() -> Void)?
    open var callbackOnCloseConnection: (() -> Void)?
    
    var isOpen = false

    deinit{
        if let inputStr = self.inputStream{
            inputStr.close()
            inputStr.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        }
        if let outputStr = self.outputStream{
            outputStr.close()
            outputStr.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        }
    }
    
    open func createConnection(_ token: Token){
        if (token.port>0) {
            Stream.getStreamsToHost(withName: "osmo.mobi", port: token.port, inputStream: &inputStream, outputStream: &outputStream)
            if inputStream != nil && outputStream != nil {
                isOpen = false
                inputStream!.delegate = self
                outputStream!.delegate = self

                inputStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
                outputStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
                
                inputStream!.setProperty(StreamSocketSecurityLevel.tlSv1.rawValue, forKey: Stream.PropertyKey.socketSecurityLevelKey)
                outputStream!.setProperty(StreamSocketSecurityLevel.tlSv1.rawValue, forKey: Stream.PropertyKey.socketSecurityLevelKey)
                
                inputStream!.open()
                outputStream!.open()
            } else {
                log.enqueue("createConnection ERROR: nil stream")
            }
        }
    }
    
    final func openCompleted(stream: Stream){
        log.enqueue("stream openCompleted")
        if(inputStream?.streamStatus == .open && outputStream?.streamStatus == .open){
            if isOpen == false {
                isOpen = true
                log.enqueue("input and output streams opened")
                if (callbackOnConnect != nil) {
                    DispatchQueue.main.async {
                        self.callbackOnConnect!()
                    }
                }
            }
        }
    }
    
    open func closeConnection() {
        log.enqueue("closing input and output streams")
        
        if (inputStream != nil) {
            inputStream?.delegate = nil
            inputStream?.close()
            inputStream?.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            
        }
        if (outputStream != nil) {
            outputStream?.delegate = nil
            outputStream?.close()
            outputStream?.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        }
        isOpen = false
        if (self.callbackOnCloseConnection != nil) {
            DispatchQueue.main.async {
                self.callbackOnCloseConnection!()
            }
        }
        self.callbackOnConnect = nil
    }

    final func writeToStream(){
        if self.outputStream != nil {
            if _messagesQueue.count > 0 && self.outputStream!.hasSpaceAvailable  {
                
                DispatchQueue.global().sync {
                    do  {
                        let req = self._messagesQueue.removeLast()
                        self.log.enqueue("c: \(req)")
                        let message = "\(req)\n"
                        if let outputStream = self.outputStream, let data = message.data(using: String.Encoding.utf8) {
                            if (self.callbackOnSendStart != nil) {
                                self.callbackOnSendStart!()
                            }
                            let wb = outputStream.write((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
                            if (wb == -1 ) {
                                self._messagesQueue.append(message)
                                self.log.enqueue("error: write to output stream")
                                if self.callbackOnError != nil {
                                    self.callbackOnError!(true)
                                }
                                return
                            }
                            if (self.callbackOnSendEnd != nil) {
                                self.callbackOnSendEnd!()
                            }
                        } else {
                            self.log.enqueue("error: send request")
                            if self.callbackOnError != nil {
                                self.callbackOnError!(true)
                            }
                        }
                    }catch{
                        self.log.enqueue("error: writeToStream")
                        if self.callbackOnError != nil {
                            self.callbackOnError!(true)
                        }
                    }
                }
            }
        }
    }
    
    final func send(message:String){
        let command = message.components(separatedBy: "|").first!
        if command == AnswTags.buffer.rawValue {
            var idx = 0;
            DispatchQueue.global().sync {
                for msg in _messagesQueue {
                    let cmd = msg.components(separatedBy: "|").first!
                    
                    if cmd == AnswTags.buffer.rawValue || cmd == AnswTags.coordinate.rawValue {
                        _messagesQueue.remove(at: idx);
                        break;
                    } else {
                        idx = idx + 1
                    }
                }
            }
            
        }
        DispatchQueue.global().sync {
            _messagesQueue.insert(message, at: 0)
        }
        if self.outputStream != nil {
            writeToStream()
        }
    }
    
    
    open func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch (eventCode) {
            
        case Stream.Event():
            print ("None")
   
        case Stream.Event.endEncountered:
            log.enqueue("stream endEcountered")
            
            if callbackOnError != nil {
                let reconnect =  aStream == self.inputStream ? false : true
                callbackOnError!(reconnect)
            }
            return
   
        case Stream.Event.openCompleted:
            openCompleted(stream: aStream)

        case Stream.Event.errorOccurred:
            log.enqueue("stream was handle error, connection is out")
            if callbackOnError != nil {
                callbackOnError!(true)
            }
        case Stream.Event.hasSpaceAvailable:
            print("HasSpaceAvailable")
            writeToStream()
            break
        case Stream.Event.hasBytesAvailable:
            print("HasBytesAvailable")
            
            let bufferSize = 1024
            var buffer = [UInt8](repeating: 0, count: bufferSize)
            var len: Int = 0
            var message = ""
            if let iStream = inputStream {
                if (callbackOnSendStart != nil) {
                    callbackOnSendStart!()
                }
               
                while(iStream.hasBytesAvailable) {
                    len = iStream.read(&buffer, maxLength: bufferSize)
                    if len > 0 {
                        if let output = NSString(bytes: &buffer, length: len, encoding: String.Encoding.utf8.rawValue) {
                            message = "\(message)\(output)"
                        }
                    }
                }
                if (callbackOnSendEnd != nil) {
                    callbackOnSendEnd!()
                }
            } else {
                log.enqueue("Stream is empty")
                
                return
            }

            if !message.isEmpty {
                
                //check for spliting:
                let responceSplit = message.components(separatedBy: "\n")
                var count = 0
                for res in responceSplit {
                    if !res.isEmpty{
                        let subst = message[Range(message.characters.index(message.endIndex, offsetBy: -1)..<message.endIndex)]
                        if responceSplit.count < 2 && subst != "\n"{
                            return
                        } else {
                            log.enqueue("s: \(res)")
                            
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
            log.enqueue("Some unhandled event \(eventCode) was occured in stream")
        }
    }
}
