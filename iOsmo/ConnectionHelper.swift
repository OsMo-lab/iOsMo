//
//  ConnectionHelper.swift
//  iOsmo
//
//  Created by Olga Grineva on 23/03/15.
//  Modified by Alexey Sirotkin on 08/08/16.
//  Copyright (c) 2015 Olga Grineva, (c) 2016 Alexey Sirotkin. All rights reserved.
//

import Foundation

fileprivate func < <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l < r
  case (nil, _?):
    return true
  default:
    return false
  }
}

fileprivate func > <T : Comparable>(lhs: T?, rhs: T?) -> Bool {
  switch (lhs, rhs) {
  case let (l?, r?):
    return l > r
  default:
    return rhs < lhs
  }
}


struct ConnectionHelper {
    
    static let authUrl = URL(string: "https://api.osmo.mobi/new?")
    static let servUrl = URL(string: "https://api.osmo.mobi/serv?") // to get server info
    static let iOsmoAppKey = "gg74527-jJRrqJ18kApQ1o7"
    /// [Register device to the server]
    
    static func postRequest (_ url: URL, requestBody: NSString, postCompleted : @escaping (_ succeeded: Bool, _ res: NSDictionary) -> ()) {
        let session = URLSession.shared;
        var urlReq = URLRequest(url: url);
        
        urlReq.httpMethod = "POST"
        urlReq.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        //urlReq.setValue("application/x-www-form-urlencoded; charset=utf-8", forHTTPHeaderField: "Content-Type")
        //urlReq.setValue("application/json", forHTTPHeaderField: "Accept")
        urlReq.httpBody = requestBody.data(using: String.Encoding.utf8.rawValue)
        let task = session.dataTask(with: urlReq as URLRequest) {(data, response, error) in
            var res : NSDictionary = [:]
            guard let data = data, let _:URLResponse = response, error == nil else {
                print("error: on send post request")
                LogQueue.sharedLogQueue.enqueue("error: on send post request")
                postCompleted(false, res)
                return
            }
            let dataStr = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            
            print("send post request \(url.absoluteURL):\(requestBody)\n answer: \(dataStr)")
            LogQueue.sharedLogQueue.enqueue("send post request \(requestBody), answer: \(dataStr)")

            do {
                let jsonDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers);
                res = (jsonDict as? NSDictionary)!
                postCompleted(true, res)
            } catch {
                print("error serializing JSON from POST")
                LogQueue.sharedLogQueue.enqueue("error serializing JSON from POST")
                postCompleted(false, res)
                return
            }
        }
        task.resume()
    }
    
    static func authenticate(completed : @escaping (_ key: NSString?) -> ()) -> Void{
        LogQueue.sharedLogQueue.enqueue("authenticate")
        let key = SettingsManager.getKey(SettingKeys.device)
        if key == nil || key!.length == 0{
            let vendorKey = UIDevice.current.identifierForVendor!.uuidString
            let model = UIDevice.current.model
            let version = UIDevice.current.systemVersion
            print("Authenticate:getting key from server")
            let requestString = "app=\(iOsmoAppKey)&id=\(vendorKey)&imei=0&platform=\(model) iOS \(version)"
            self.postRequest(authUrl!, requestBody: requestString as NSString, postCompleted: {result, responceData -> Void in
                if result {
                    if let newKey = responceData.object(forKey: Keys.key.rawValue) as? NSString {
                        print ("got key by post request \(newKey)")
                        LogQueue.sharedLogQueue.enqueue("got key by post request")
                        SettingsManager.setKey(newKey, forKey: SettingKeys.device)
                        completed(newKey)
                    } else {
                        completed(nil)
                    }
                } else {
                    completed(nil)
                }
            })
        } else {
            print("Authenticate:using local key")
            completed(key)
        }
    }
    
    static func getServerInfo( completed : @escaping (_ succeeded: Bool, _ res: Token?) -> ()) -> Void {
        authenticate(completed: {key -> Void in
            if (key != nil) {
                let requestString = "app=\(iOsmoAppKey)"
                
                postRequest(servUrl!, requestBody: requestString as NSString, postCompleted: {result, responceData -> Void in
                    if result {
                        LogQueue.sharedLogQueue.enqueue("get server info by post request")
                        
                        if let err = responceData.object(forKey: Keys.error.rawValue) as? NSNumber , let errDesc = responceData.object(forKey: Keys.errorDesc.rawValue) as? NSString {
                            
                            let tkn = Token(tokenString: "", address: "", port: 0, key: "")
                            tkn.error = errDesc as String
                            
                            completed(false,tkn)
                        }  else {
                            if let server = responceData.object(forKey: Keys.address.rawValue) as? NSString {
                                print("server is \(server)")
                                LogQueue.sharedLogQueue.enqueue("server is \(server)")
                                
                                let server = server.components(separatedBy: ":")
                                
                                if let tknAddress = server[0] as? String, let tknPort = Int(server[1]) {
                                    
                                    let tkn =  Token(tokenString:"", address: tknAddress as NSString, port: tknPort, key: key!)
                                    completed(true,tkn)
                                }
                            }
                            
                        }
                        
                    } else {
                        let tkn = Token(tokenString: "", address: "", port: 0, key: "")
                        tkn.error = "Unable to connect to server"
                        
                        completed(false,tkn)
                    }
                })
                
            } else {
                let tkn = Token(tokenString: "", address: "", port: 0, key: "")
                tkn.error = "Unable to receive token"

                completed(false,tkn)
            }
            
        })
    }
}
