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
    static let prepareUrl = URL(string: "https://api.osmo.mobi/init?") // to get token
    static let servUrl = URL(string: "https://api.osmo.mobi/serv?") // to get server info
    static let iOsmoAppKey = "gg74527-jJRrqJ18kApQ1o7"
    /// [Register device to the server]
    static func authenticate() -> NSString? {
        
        LogQueue.sharedLogQueue.enqueue("get key")
        var key = SettingsManager.getKey(SettingKeys.device)
        if key == nil || key!.length == 0{
            
            let vendorKey = UIDevice.current.identifierForVendor!.uuidString
            let model = UIDevice.current.model
            let version = UIDevice.current.systemVersion
            
            let responseData = sendPostRequest(authUrl!, requestBody: "app=\(iOsmoAppKey)&id=\(vendorKey)&imei=0&platform=\(model) iOS \(version)" as NSString)
            
            if let response = responseData, let newKey = response.object(forKey: Keys.key.rawValue) as? NSString {
                print ("got auth response")
                LogQueue.sharedLogQueue.enqueue("got key by post request")
                SettingsManager.setKey(newKey, forKey: SettingKeys.device)
                key = newKey
            } else {
                return nil
            }
        }
        print("device key\(key)")
        
        //5 = 9C7tNWXcxRziR6rkG7PiQXzP7Vriy3FgF5WLhYeXOz3lDJOidx3kiCJNccPQsORj
        //iPad = j1aZppa8cdti5MqkfHjRj86LJIKv2OFmjnsjrDRzLmws4E4ipYwLnrjBJ70WOnAJ
        return key
        
    }
    
    static func getToken() -> Token? {
        
        if let key = authenticate() {
            
            var requestString = "app=\(iOsmoAppKey)&device=\(key)"
            
            let auth = SettingsManager.getKey(SettingKeys.auth)
            if auth != nil && auth?.length > 0 {
                
                requestString += "&user=\(auth!)"
            }
            
            if let responceData = sendPostRequest(prepareUrl!, requestBody: requestString as NSString) {
                
                LogQueue.sharedLogQueue.enqueue("get token by post request")
                
                if let err = responceData.object(forKey: Keys.error.rawValue) as? NSNumber , let errDesc = responceData.object(forKey: Keys.errorDesc.rawValue) as? NSString {
                    
                    let tkn = Token(tokenString: "", address: "", port: 0, key:"")
                    tkn.error = errDesc as String
                    return tkn
                }
                else {
                    
                    if let usr = responceData.object(forKey: Keys.name.rawValue) as? NSString {
                        
                        SettingsManager.setKey(usr, forKey: SettingKeys.user)
                    }
                    else {  SettingsManager.setKey("", forKey: SettingKeys.user)}
                    
                    if let tkn = responceData.object(forKey: Keys.token.rawValue) as? NSString,
                        let server = responceData.object(forKey: Keys.address.rawValue) as? NSString {
                            
                            LogQueue.sharedLogQueue.enqueue("token is \(tkn)")
                            
                            let server = server.components(separatedBy: ":")
                            let tknAddress = server[0]
                            if let tknPort = Int(server[1]) {
                                
                                return Token(tokenString: tkn, address: tknAddress as NSString, port: tknPort, key:"")
                            }
                    }

                }
                
            }
        }
        
        return nil
    }
    
    static func connectToServ() -> Token? {
        
        if let key = authenticate() {
            
            let requestString = "app=\(iOsmoAppKey)"
            
            if let responceData = sendPostRequest(servUrl!, requestBody: requestString as NSString) {
                
                LogQueue.sharedLogQueue.enqueue("get server info by post request")
                
                if let err = responceData.object(forKey: Keys.error.rawValue) as? NSNumber , let errDesc = responceData.object(forKey: Keys.errorDesc.rawValue) as? NSString {
                    
                    let tkn = Token(tokenString: "", address: "", port: 0, key: "")
                    tkn.error = errDesc as String
                    return tkn
                }
                else {
                    if let server = responceData.object(forKey: Keys.address.rawValue) as? NSString {
                        
                        LogQueue.sharedLogQueue.enqueue("server is \(server)")
                        
                        let server = server.components(separatedBy: ":")
                        
                        if let tknAddress = server[0] as? String, let tknPort = Int(server[1]) {
                            
                            return Token(tokenString:"", address: tknAddress as NSString, port: tknPort, key: key)
                        }
                    }
                    
                }
                
            }
        }
        
        return nil
    }
    
    static func sendPostRequest(_ url: URL, requestBody: NSString) -> NSDictionary? {
        
        let request = NSMutableURLRequest(url: url)
        
        if let data = NSString(string: requestBody).data(using: String.Encoding.utf8.rawValue){
            
            request.httpMethod = "POST"
            request.httpBody = data
            
            var responce: URLResponse?
            do {
               
                let responseData = try NSURLConnection.sendSynchronousRequest(request as URLRequest, returning: &responce);
                    
                    if let responseString = NSString(data: responseData, encoding: String.Encoding.utf8.rawValue){
                    
                        print("send post request \(requestBody), answer: \(responseString)")
                        LogQueue.sharedLogQueue.enqueue("send post request, answer: \(responseString)")
                        
                    }
                    else {
                        
                        print("error: on parsing answer of post request")
                        LogQueue.sharedLogQueue.enqueue("error: on parsing answer of post request")
                    }
                
                do {
                    let jsonDict = try JSONSerialization.jsonObject(with: responseData, options: JSONSerialization.ReadingOptions.mutableContainers);
                    
                        
                    return jsonDict as? NSDictionary;
                    
                    
                }catch {
                    print("error serializing JSON: \(error)")
                }
                

            } catch (let _) {
                
            }
        }
        
        return nil
    }
}
