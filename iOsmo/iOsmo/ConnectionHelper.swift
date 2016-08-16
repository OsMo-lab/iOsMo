//
//  ConnectionHelper.swift
//  iOsmo
//
//  Created by Olga Grineva on 23/03/15.
//  Modified by Alexey Sirotkin on 08/08/16.
//  Copyright (c) 2015 Olga Grineva. All rights reserved.
//

import Foundation

struct ConnectionHelper {
    
    static let authUrl = NSURL(string: "https://api.osmo.mobi/new?")
    static let prepareUrl = NSURL(string: "https://api.osmo.mobi/init?") // to get token
    static let servUrl = NSURL(string: "https://api.osmo.mobi/serv?") // to get server info
    static let iOsmoAppKey = "gg74527-jJRrqJ18kApQ1o7"
    /// [Register device to the server]
    static func authenticate() -> NSString? {
        
        LogQueue.sharedLogQueue.enqueue("get key")
        var key = SettingsManager.getKey(SettingKeys.device)
        
        if key == nil || key!.length == 0{
            
            let vendorKey = UIDevice.currentDevice().identifierForVendor!.UUIDString
            
            //TODO: platform - real platform needed
            let responseData = sendPostRequest(authUrl!, requestBody: "app=\(iOsmoAppKey)&id=\(vendorKey)&imei=0&platform=iphone")
            
            if let response = responseData, newKey = response.objectForKey(Keys.key.rawValue) as? NSString {
                print ("got auth response")
                LogQueue.sharedLogQueue.enqueue("got key by post request")
                SettingsManager.setKey(newKey, forKey: SettingKeys.device)
                key = newKey
            }
            else {return nil}
        }
        return key
        
    }
    
    static func getToken() -> Token? {
        
        if let key = authenticate() {
            
            var requestString = "app=\(iOsmoAppKey)&device=\(key)"
            
            let auth = SettingsManager.getKey(SettingKeys.auth)
            if auth != nil && auth?.length > 0 {
                
                requestString += "&user=\(auth!)"
            }
            
            if let responceData = sendPostRequest(prepareUrl!, requestBody: requestString) {
                
                LogQueue.sharedLogQueue.enqueue("get token by post request")
                
                if let err = responceData.objectForKey(Keys.error.rawValue) as? NSNumber , errDesc = responceData.objectForKey(Keys.errorDesc.rawValue) as? NSString {
                    
                    let tkn = Token(tokenString: "", address: "", port: 0, key:"")
                    tkn.error = errDesc as String
                    return tkn
                }
                else {
                    
                    if let usr = responceData.objectForKey(Keys.name.rawValue) as? NSString {
                        
                        SettingsManager.setKey(usr, forKey: SettingKeys.user)
                    }
                    else {  SettingsManager.setKey("", forKey: SettingKeys.user)}
                    
                    if let tkn = responceData.objectForKey(Keys.token.rawValue) as? NSString,
                        server = responceData.objectForKey(Keys.address.rawValue) as? NSString {
                            
                            LogQueue.sharedLogQueue.enqueue("token is \(tkn)")
                            
                            let server = server.componentsSeparatedByString(":")
                            
                            if let tknAddress = server[0] as? String, tknPort = Int(server[1]) {
                                
                                return Token(tokenString: tkn, address: tknAddress, port: tknPort, key:"")
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
            
            if let responceData = sendPostRequest(servUrl!, requestBody: requestString) {
                
                LogQueue.sharedLogQueue.enqueue("get server info by post request")
                
                if let err = responceData.objectForKey(Keys.error.rawValue) as? NSNumber , errDesc = responceData.objectForKey(Keys.errorDesc.rawValue) as? NSString {
                    
                    let tkn = Token(tokenString: "", address: "", port: 0, key: "")
                    tkn.error = errDesc as String
                    return tkn
                }
                else {
                    
                    if let usr = responceData.objectForKey(Keys.name.rawValue) as? NSString {
                        
                        SettingsManager.setKey(usr, forKey: SettingKeys.user)
                    }
                    else {  SettingsManager.setKey("", forKey: SettingKeys.user)}
                    
                    if let server = responceData.objectForKey(Keys.address.rawValue) as? NSString {
                        
                        LogQueue.sharedLogQueue.enqueue("server is \(server)")
                        
                        let server = server.componentsSeparatedByString(":")
                        
                        if let tknAddress = server[0] as? String, tknPort = Int(server[1]) {
                            
                            return Token(tokenString:"", address: tknAddress, port: tknPort, key: key)
                        }
                    }
                    
                }
                
            }
        }
        
        return nil
    }
    
    static func sendPostRequest(url: NSURL, requestBody: NSString) -> NSDictionary? {
        
        let request = NSMutableURLRequest(URL: url)
        
        if let data = NSString(string: requestBody).dataUsingEncoding(NSUTF8StringEncoding){
            
            request.HTTPMethod = "POST"
            request.HTTPBody = data
            
            var responce: NSURLResponse?
            do {
               
                let responseData = try NSURLConnection.sendSynchronousRequest(request, returningResponse: &responce);
                    
                    if let responseString = NSString(data: responseData, encoding: NSUTF8StringEncoding){
                    
                        print("send post request \(requestBody), answer: \(responseString)")
                        LogQueue.sharedLogQueue.enqueue("send post request, answer: \(responseString)")
                        
                    }
                    else {
                        
                        print("error: on parsing answer of post request")
                        LogQueue.sharedLogQueue.enqueue("error: on parsing answer of post request")
                    }
                
                do {
                    let jsonDict = try NSJSONSerialization.JSONObjectWithData(responseData, options: NSJSONReadingOptions.MutableContainers);
                    
                        
                    return jsonDict as! NSDictionary;
                    
                    
                }catch {
                    print("error serializing JSON: \(error)")
                }
                

            } catch (let _) {
                
            }
        }
        
        return nil
    }
}
