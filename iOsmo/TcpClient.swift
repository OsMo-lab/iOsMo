//
//  TcpClient.swift
//  iOsmo
//
//  Created by Olga Grineva on 25/03/15.
//  Copyright (c) 2014 Olga Grineva, (c) 2016 Alexey Sirotkin. All rights reserved.
//

import Foundation

open class TcpClient : NSObject, StreamDelegate {

    let log = LogQueue.sharedLogQueue
    private var inputStream: InputStream?
    private var outputStream: OutputStream?
    private var openedStreams = 0;
    // MARK: - NSStreamDelegate
    open var callbackOnParse: ((String) -> Void)?
    open var callbackOnError: ((Bool) -> Void)?
    open var callbackOnSendStart: (() -> Void)?
    open var callbackOnSendEnd: (() -> Void)?
    open var callbackOnConnect: (() -> Void)?
    
    
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
        openedStreams = 0
        if (token.port>0) {
            Stream.getStreamsToHost(withName: "osmo.mobi", port: token.port, inputStream: &inputStream, outputStream: &outputStream)
            if inputStream != nil && outputStream != nil {
                
                inputStream!.delegate = self
                outputStream!.delegate = self

                inputStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
                //RunLoop.current
                outputStream!.schedule(in: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
                
                inputStream!.setProperty(StreamSocketSecurityLevel.tlSv1.rawValue, forKey: Stream.PropertyKey.socketSecurityLevelKey)
                
                
                
                inputStream!.open()
                print("opening input stream")
            
                outputStream!.setProperty(StreamSocketSecurityLevel.tlSv1.rawValue, forKey: Stream.PropertyKey.socketSecurityLevelKey)
                
                
                outputStream!.open()
                print("opening output stream")
            }
            
            log.enqueue("create connection, input and output streams")
            print("create connection, input and output streams")
        }
    }
    
    final func openCompleted(stream: Stream){
        if(self.inputStream?.streamStatus == .open && self.outputStream?.streamStatus == .open && openedStreams == 2){
            print("streams opened")
            log.enqueue("streams opened")
            if (self.callbackOnConnect != nil) {
                DispatchQueue.main.async {
                    self.callbackOnConnect!()
                }
            }
        }
    }
    
    open func closeConnection() {
        if ((inputStream != nil) && (outputStream != nil)) {
            log.enqueue("closing input and output streams")
            print("closing input and output streams")
            inputStream?.delegate = nil
            inputStream?.close()
            inputStream?.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
            
            outputStream?.delegate = nil
            outputStream?.close()
            outputStream?.remove(from: RunLoop.main, forMode: RunLoopMode.defaultRunLoopMode)
        }
    }
    
    open func send(_ request: String){
        log.enqueue("r: \(request)")
        print("r: \(request)")
        let requestToSend = "\(request)\n"
        if let outputStream = outputStream, let data = requestToSend.data(using: String.Encoding.utf8) {
            if (callbackOnSendStart != nil) {
                callbackOnSendStart!()
            }
            let wb = outputStream.write((data as NSData).bytes.bindMemory(to: UInt8.self, capacity: data.count), maxLength: data.count)
            if (wb == -1 ) {
                log.enqueue("error: write to output stream")
                print("error: write to output stream")
                if callbackOnError != nil {
                    callbackOnError!(true)
                }
                return
            }
            print("sended")
            if (callbackOnSendEnd != nil) {
                callbackOnSendEnd!()
            }
        } else {
            log.enqueue("error: send request")
            print("error: send request")
        }
    }

    
    fileprivate var message: String = ""
    
    open func stream(_ aStream: Stream, handle eventCode: Stream.Event) {
        switch (eventCode) {
            
        case Stream.Event():
            print ("None")
   
        case Stream.Event.endEncountered:
            print ("EndEncountered")
            log.enqueue("stream endEcountered")
            inputStream?.close()
            outputStream?.close()
            if callbackOnError != nil {
                callbackOnError!(true)
            }
            return
   
        case Stream.Event.openCompleted:
            openedStreams = openedStreams + 1
            openCompleted(stream: aStream)

        case Stream.Event.errorOccurred:
            //("stream was handle error, connection is out")
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
                if (callbackOnSendStart != nil) {
                    callbackOnSendStart!()
                }
               
                while(iStream.hasBytesAvailable)
                {
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
                print("Stream is empty")
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
