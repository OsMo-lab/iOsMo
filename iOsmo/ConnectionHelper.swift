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
    static let iOsmoAppKey = "hD74_vDa3Lc_3rDs"
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
                postCompleted(false, res)
                return
            }
            let dataStr = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            
            print("send post request \(url.absoluteURL):\(requestBody)\n answer: \(dataStr)")
            do {
                let jsonDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers);
                res = (jsonDict as? NSDictionary)!
                postCompleted(true, res)
            } catch {
                print("error serializing JSON from POST")
                postCompleted(false, res)
            }
        }
        task.resume()
    }
    
    static func downloadRequest (_ url: URL, completed : @escaping (_ succeeded: Bool, _ res: Data?) -> ()) {
        let session = URLSession.shared;
        var urlReq = URLRequest(url: url);
        
        urlReq.httpMethod = "GET"
        urlReq.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData
        let task = session.downloadTask(with: urlReq, completionHandler:  {(url, response, error) in
            if url != nil {
                let data:Data! = try? Data(contentsOf: url!)
                do {
                    completed(true, data)
                } catch {
                    completed(false, nil)
                }
                
            }
        })
        task.resume()
    }
    
    static func authenticate(completed : @escaping (_ key: String?) -> ()) -> Void{
        let device = SettingsManager.getKey(SettingKeys.device)
        if device == nil || device?.length == 0{
            let vendorKey = UIDevice.current.identifierForVendor!.uuidString
            let model = UIDevice.current.model
            let version = UIDevice.current.systemVersion
            print("Authenticate:getting key from server")
            let requestString = "app=\(iOsmoAppKey)&id=\(vendorKey)&imei=0&platform=\(model) iOS \(version)"
            self.postRequest(authUrl!, requestBody: requestString as NSString, postCompleted: {result, responceData -> Void in
                if result {
                    if let newKey = responceData.object(forKey: Keys.device.rawValue) as? String {
                        print ("got key by post request \(newKey)")
                        SettingsManager.setKey(newKey as NSString, forKey: SettingKeys.device)
                        completed(newKey)
                    } else {
                        completed(nil)
                    }
                } else {
                    completed(nil)
                }
            })
        } else {
            print("Authenticate:using local key \(device)")
            completed((device as! String))
        }
    }
    
    static func getServerInfo( completed : @escaping (_ succeeded: Bool, _ res: Token?) -> ()) -> Void {
        authenticate(completed: {key -> Void in
            if (key != nil) {
                print("Authenticated with key")
                let requestString = "app=\(iOsmoAppKey)"
                
                postRequest(servUrl!, requestBody: requestString as NSString, postCompleted: {result, responceData -> Void in
                    var tkn : Token?;
                    if result {
                        print("get server info by post request")
                        
                        if let err = responceData.object(forKey: Keys.error.rawValue) as? NSNumber , let errDesc = responceData.object(forKey: Keys.errorDesc.rawValue) as? NSString {
                            
                            tkn = Token(tokenString: "", address: "", port: 0, key: "")
                            tkn?.error = errDesc as String
                            completed(false,tkn)
                            return
                        }  else {
                            if let server = responceData.object(forKey: Keys.address.rawValue) as? NSString {
                                print("server is \(server)")
                                
                                let server_arr = server.components(separatedBy: ":")
                                if server_arr.count > 1 {
     
                                    
                                    if let tknPort = Int(server_arr[1]) {
                                        tkn =  Token(tokenString:"", address: server_arr[0], port: tknPort, key: key! as String)
                                        completed(true,tkn)
                                        return
                                    }
                                }
                            }
                        }
                    } else {
                        print("Unable to connect to server")
                    }
                    if (tkn == nil) {
                        tkn = Token(tokenString: "", address: "", port: 0, key: "")
                        completed(false,tkn)
                        return
                    }
                })
            } else {
                print("Unable to receive token")
                let tkn = Token(tokenString: "", address: "", port: 0, key: "")
                completed(false,tkn)
            }
        })
    }
}
