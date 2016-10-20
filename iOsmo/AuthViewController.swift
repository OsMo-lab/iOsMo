//
//  AuthViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 22/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import UIKit

protocol AuthResultProtocol {
    
    func succesfullLoginWithToken (_ controller: AuthViewController, info : AuthInfo) -> Void
    func loginCancelled (_ controller: AuthViewController) -> Void
    
    
}

open class AuthViewController: UIViewController, UIWebViewDelegate {

    let authAnswerScheme = "api.osmo.mobi"
    @IBOutlet weak var authView: UIWebView!
    
    @IBAction func OnReload(_ sender: AnyObject) {
        reload()
    
    }
    @IBAction func OnCancel(_ sender: AnyObject) {
        
        delegate?.loginCancelled(self)
    }
    
    var delegate: AuthResultProtocol?    
    
    override open func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        reload()
    }

    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */


    func reload(){
        let device = SettingsManager.getKey(SettingKeys.device) as! String
        let url = "https://osmo.mobi/signin?type=m&key=\(device)"
        if let checkURL = URL(string: url as String) {
            if let auth = authView  {
                let urlRequest = URLRequest(url: checkURL)
                auth.loadRequest(urlRequest)
            }
            
        } else {
            print("wrong request")
        }
        
    }
    
    
    open func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        
        
        if let url = request.url, let host = url.host {
            
            if host == authAnswerScheme {
                
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if let comp = components {
                    
                    if #available(iOS 8, *){
                        let queryItems = comp.queryItems
                        
                        if let u = queryItems!.filter({m in m.name == "nick"}).first , let user = u.value,
                            let p = queryItems!.filter({m in m.name == "user"}).first , let passKey = p.value {
                                print("auth user: \(user) with passkey: \(passKey)")
                                LogQueue.sharedLogQueue.enqueue("auth user: \(user) with passkey: \(passKey)")
                                
                                delegate?.succesfullLoginWithToken(self, info: AuthInfo(accountName: user, key: passKey))
                        }
                    }
                    else {
                        
                        if let user = url.queryParams()["nick"] as? String, let passKey = url.queryParams()["user"] as? String {
                            
                            print("auth user: \(user) with passkey: \(passKey)")
                            LogQueue.sharedLogQueue.enqueue("auth user: \(user) with passkey: \(passKey)")
                            
                            delegate?.succesfullLoginWithToken(self, info: AuthInfo(accountName: user, key: passKey))
                        }
                       
                    }
                   
                }
                
                return false
            }
        }

        return true
    }
    
    open func webView(_ webView: UIWebView, didFailLoadWithError error: Error) {
        //
    }
    
    open func webViewDidStartLoad(_ webView: UIWebView) {
        //show loading indicator
        UIApplication.shared.isNetworkActivityIndicatorVisible = true
    }
    
    
    open func webViewDidFinishLoad(_ webView: UIWebView) {
        //hide loading indicator
        UIApplication.shared.isNetworkActivityIndicatorVisible = false
    }
}





