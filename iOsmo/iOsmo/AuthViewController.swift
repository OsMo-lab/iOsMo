//
//  AuthViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 22/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import UIKit

protocol AuthResultProtocol {
    
    func succesfullLoginWithToken (controller: AuthViewController, info : AuthInfo) -> Void
    func loginCancelled (controller: AuthViewController) -> Void
    
    
}

public class AuthViewController: UIViewController, UIWebViewDelegate {

    let authAnswerScheme = "api.osmo.mobi"
    @IBOutlet weak var authView: UIWebView!
    
    @IBAction func OnReload(sender: AnyObject) {
        reload()
    
    }
    @IBAction func OnCancel(sender: AnyObject) {
        
        delegate?.loginCancelled(self)
    }
    
    var delegate: AuthResultProtocol?
    
    
    override public func viewDidLoad() {
        super.viewDidLoad()

        // Do any additional setup after loading the view.
        reload()
    }

    override public func didReceiveMemoryWarning() {
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
        
        let url = NSString(string: "https://osmo.mobi/signin?type=m")
        if let checkURL = NSURL(string: url as String) {
            
            if let auth = authView  {
                
                let urlRequest = NSURLRequest(URL: checkURL)
                auth.loadRequest(urlRequest)
            }
            
        }
        else
        {
            print("wrong request")
        }
        
    }
    
    
    public func webView(webView: UIWebView, shouldStartLoadWithRequest request: NSURLRequest, navigationType: UIWebViewNavigationType) -> Bool {
        
        
        if let url = request.URL, host = url.host {
            
            if host == authAnswerScheme {
                
                let components = NSURLComponents(URL: url, resolvingAgainstBaseURL: false)
                if let comp = components {
                    
                    let aSelector : Selector = #selector(NSProcessInfo.isOperatingSystemAtLeastVersion(_:))
                    let higher8 = NSProcessInfo.instancesRespondToSelector(aSelector)
                    
                    if higher8 {
                        
                        let queryItems = comp.queryItems

                        
                        if let u = queryItems!.filter({m in m.name == "nick"}).first , user = u.value,
                            p = queryItems!.filter({m in m.name == "user"}).first , passKey = p.value {
                                print("auth user: \(user) with passkey: \(passKey)")
                                LogQueue.sharedLogQueue.enqueue("auth user: \(user) with passkey: \(passKey)")
                                
                                delegate?.succesfullLoginWithToken(self, info: AuthInfo(accountName: user, key: passKey))
                        }
                        
                    }
                    else {
                        
                        if let user = url.queryParams()["nick"] as? String, passKey = url.queryParams()["user"] as? String {
                            
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
    
    public func webView(webView: UIWebView, didFailLoadWithError error: NSError?) {
        //
    }
    
    public func webViewDidStartLoad(webView: UIWebView) {
        //show loading indicator
        UIApplication.sharedApplication().networkActivityIndicatorVisible = true
    }
    
    
    public func webViewDidFinishLoad(webView: UIWebView) {
        //hide loading indicator
        UIApplication.sharedApplication().networkActivityIndicatorVisible = false
    }
}





