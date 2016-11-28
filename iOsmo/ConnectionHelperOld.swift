//
//  ConnectionHelper.swift
//  iOsmo
//
//  Created by Olga Grineva on 14/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//
// Authenticate is SYNCHRONEOUS
//prepare?key=...&protocol=1&client=IOsMo&auth=....


import Foundation

struct ConnectionHelperOld{
    
    static let authUrl = NSURL(string: "https://api.osmo.mobi/auth")
    static let prepareUrl = NSURL(string: "https://api.osmo.mobi/prepare")
    
    static func authenticate() -> NSString {
        
        LogQueue.sharedLogQueue.enqueue("get key")
        var key = SettingsManager.getKey(SettingKeys.device)
        
        if key == nil || key!.length == 0{
            
            let vendorKey = UIDevice.currentDevice().identifierForVendor!.UUIDString
            let responseData = sendPostRequest(authUrl!, requestBody: "model=Iphone&imei=0&client=iOsmo&android_id=\(vendorKey)")
            
            key = responseData.objectForKey(KeysOld.key.rawValue) as? NSString
            
            LogQueue.sharedLogQueue.enqueue("get key by post request")
            SettingsManager.setKey(key!, forKey: SettingKeys.device)
        }
        
        return key!
        
    }
    
    static func getToken() -> Token? {
        
        let key = authenticate()
        
        var requestString = "key=\(key)&protocol=1&client=iOsmo"
        
        let auth = SettingsManager.getKey(SettingKeys.auth)
        if auth != nil && auth?.length > 0 {
            
            requestString += "&auth=\(auth!)"
        }
        
        
        let responceData = sendPostRequest(prepareUrl!, requestBody: requestString)
        LogQueue.sharedLogQueue.enqueue("get token by post request")

       
        var tknString, tknAddress: NSString?
        var tknPort: Int?
        if let tokenValue = responceData.objectForKey(Keys.token.rawValue) as? NSString{
            tknString = tokenValue as NSString
            LogQueue.sharedLogQueue.enqueue("token is \(tknString)")
        }
       
        if let serverValue = (responceData.objectForKey(Keys.address.rawValue) as? NSString){
            
            let server = serverValue.componentsSeparatedByString(":")
            
            tknAddress = server[0]
            tknPort = Int(server[1])
            
        }
        
        if tknString != nil && tknAddress != nil && tknPort != nil {
            return Token(tokenString: tknString!, address: tknAddress!, port: tknPort!, key:"")
        }
        
        return nil
        
    }
    
    static func sendPostRequest(url: NSURL, requestBody: NSString) -> NSDictionary{
        
        let request = NSMutableURLRequest(URL: url)
        
        let data = NSString(string: requestBody).dataUsingEncoding(NSUTF8StringEncoding)
        
        request.HTTPMethod = "POST"
        request.HTTPBody = data!

        var responce: NSURLResponse?
        

        do {
            
            let responseData = try NSURLConnection.sendSynchronousRequest(request, returningResponse: &responce);
            
            if let responseString = NSString(data: responseData, encoding: NSUTF8StringEncoding){
                
                print("send post request, answer: \(responseString)")
                
                do {
                    let jsonDict: NSDictionary = try NSJSONSerialization.JSONObjectWithData(responseData, options: NSJSONReadingOptions.MutableContainers) as! NSDictionary
                    
                    return jsonDict
                
                } catch {
                    
                }
                
            }
            else {
                
                print("error: on parsing answer of post request")

            }
            /*
            let responseData = try NSURLConnection.sendSynchronousRequest(request, returningResponse: &responce)
            if let r = responseData{
                let responseString = NSString(data: r, encoding: NSUTF8StringEncoding)
                print("send post request, answer: \(responseString!)")
                
                var jsonDict: NSDictionary = NSJSONSerialization.JSONObjectWithData(r, options: NSJSONReadingOptions.MutableContainers, error: nil) as! NSDictionary
                
                return jsonDict
                
            }*/
            return NSDictionary()
        
        } catch {
            return NSDictionary()
        
        }
    }
}