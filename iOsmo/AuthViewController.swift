//
//  AuthViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 22/12/14.
//  Copyright (c) 2014 Olga Grineva. All rights reserved.
//

import UIKit


enum SignActions: Int {
    case SignIn = 1 //default
    case SignUp = 2
}
protocol AuthResultProtocol {
    
    func succesfullLoginWithToken (_ controller: AuthViewController, info : AuthInfo) -> Void
    func loginCancelled (_ controller: AuthViewController) -> Void
    
    
}

open class AuthViewController: UIViewController, UIWebViewDelegate, UITextViewDelegate, UITextFieldDelegate {

    let authAnswerScheme = "api2.osmo.mobi"
    let log = LogQueue.sharedLogQueue
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passField: UITextField!
    @IBOutlet weak var nickField: UITextField!
    @IBOutlet weak var pass2Field: UITextField!
    @IBOutlet weak var signButton: UIButton!
    @IBOutlet weak var actButton: UIButton!
    @IBOutlet weak var forgotButton: UIButton!
    
    @IBOutlet weak var sexSwitch: UISwitch!
    @IBOutlet weak var signLabel: UILabel!
    @IBOutlet weak var sexLabel: UILabel!
    @IBOutlet weak var registerView: UIView!
    @IBOutlet weak var signToRegConstraint: NSLayoutConstraint!
    @IBOutlet weak var signToPassConstraint: NSLayoutConstraint!

    
    @IBOutlet weak var authView: UIWebView!
    var signAction: SignActions = SignActions.SignIn
    
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
        //reload()
    }

    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    //Смена режима формы с логина на регистрацию и обратоно
    @IBAction func setSignMode(_ sender: UIButton) {
        if signAction == SignActions.SignIn {
            signAction = SignActions.SignUp
        } else {
            signAction = SignActions.SignIn
        }
        switch signAction {
        case SignActions.SignIn:
            signButton.setTitle(NSLocalizedString("Register", comment: "Register label"), for: .normal)
            actButton.setTitle(NSLocalizedString("Sign-In", comment: "Sign-in label"), for: .normal)
            
            signLabel.text = NSLocalizedString("Sign-In", comment: "Sign-in label")
            signToRegConstraint.priority = UILayoutPriority(rawValue: 500)
            signToPassConstraint.priority = UILayoutPriority(rawValue: 999)
            
            registerView.isHidden = true
            forgotButton.isHidden = false
        default:
            signButton.setTitle(NSLocalizedString("Sign-In", comment: "Sign-in label"), for: .normal)
            actButton.setTitle(NSLocalizedString("Register", comment: "Register label"), for: .normal)
            
            signLabel.text = NSLocalizedString("Register", comment: "Register label")
            signToRegConstraint.priority = UILayoutPriority(rawValue: 999)
            signToPassConstraint.priority = UILayoutPriority(rawValue: 500)
            
            registerView.isHidden = false
            forgotButton.isHidden = true
        }
    }

    //Выбор пола
    @IBAction func setSex(_ sender: UISwitch) {
        if sender.isOn {
            sexLabel.text = NSLocalizedString("male", comment: "male")
        } else {
            sexLabel.text = NSLocalizedString("female", comment: "female")
        }
    }
    
    @IBAction func signAction(_ sender: UIButton) {
        if (signAction == SignActions.SignUp ) {
            if (passField.text != pass2Field.text) {
                self.alert("OsMo registration", message: NSLocalizedString("Passwords didn't match!", comment: "Passwords didn't match!"))
                return
            }
            if (nickField.text == "") {
                self.alert("OsMo registration", message: NSLocalizedString("Enter nick!", comment: "Enter nick!"))
                return
            }
        }
        
        let device = SettingsManager.getKey(SettingKeys.device)! as String
        let url = URL(string: signAction == SignActions.SignIn ? "https://api2.osmo.mobi/signin?" : "https://api2.osmo.mobi/signup?")
        let session = URLSession.shared;
        var urlReq = URLRequest(url: url!);
        var requestBody:String = "key=\(device)&email=\(emailField.text!)&password=\(passField.text!)"
        if (signAction == SignActions.SignUp) {
            requestBody = "\(requestBody)&nick=\(nickField.text!)&gender=\(sexSwitch.isOn ? 1 : 0)"
        }
        
        urlReq.httpMethod = "POST"
        urlReq.cachePolicy = NSURLRequest.CachePolicy.reloadIgnoringCacheData

        urlReq.httpBody = requestBody.data(using: String.Encoding(rawValue: String.Encoding.utf8.rawValue))
        let task = session.dataTask(with: urlReq as URLRequest) {(data, response, error) in
            var res : NSDictionary = [:]
            guard let data = data, let _:URLResponse = response, error == nil else {
                print("error: on send post request")
                LogQueue.sharedLogQueue.enqueue("error: on send post request")

                return
            }
            //let dataStr = NSString(data: data, encoding: String.Encoding.utf8.rawValue)
            
            
            do {
                let jsonDict = try JSONSerialization.jsonObject(with: data, options: JSONSerialization.ReadingOptions.mutableContainers);
                res = (jsonDict as? NSDictionary)!
                print(res)
                if let user = res["nick"] {
                    DispatchQueue.main.async {
                        self.delegate?.succesfullLoginWithToken(self, info: AuthInfo(accountName: user as! String, key: ""))
                    }
                } else {
                    if let error = res["error_description"] {
                        DispatchQueue.main.async {
                            self.alert("OsMo registration", message: error as! String )
                        }
                    }
                }
            } catch {
                print("error serializing JSON from POST")
                LogQueue.sharedLogQueue.enqueue("error serializing JSON from POST")

                return
            }
        }
        task.resume()
        
    }
    
    @IBAction func forgotPassword(_ sender: UIButton) {
        UIApplication.shared.openURL(URL(string: "https://osmo.mobi/forgot")!)
    }
    
    func alert(_ title: String, message: String) {
        let myAlert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
        myAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment:"OK"), style: .default, handler: nil))
        self.present(myAlert, animated: true, completion: nil)
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
        let device = SettingsManager.getKey(SettingKeys.device)! as String
        let url = "https://osmo.mobi/signin?type=m&key=\(device)"
        log.enqueue("Authenticationg at \(url)")
        if let checkURL = URL(string: url as String) {
            if let auth = authView  {
                let urlRequest = URLRequest(url: checkURL)
                auth.loadRequest(urlRequest)
            }
            
        } else {
            print("wrong request")
        }
        
    }
    
    
    open func webView(_ webView: UIWebView, shouldStartLoadWith request: URLRequest, navigationType: UIWebView.NavigationType) -> Bool {
        
        
        if let url = request.url, let host = url.host {
            
            if host == authAnswerScheme {
                
                let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
                if let comp = components {
                    
                    if #available(iOS 8, *){
                        let queryItems = comp.queryItems
                        
                        if let u = queryItems!.filter({m in m.name == "nick"}).first , let user = u.value,
                            let p = queryItems!.filter({m in m.name == "user"}).first , let passKey = p.value {
                                print("auth user: \(user) with passkey: \(passKey)")
                                log.enqueue("auth user: \(user) with passkey: \(passKey)")
                                
                                delegate?.succesfullLoginWithToken(self, info: AuthInfo(accountName: user, key: passKey))
                        }
                    }
                    else {
                        
                        if let user = url.queryParams()["nick"] as? String, let passKey = url.queryParams()["user"] as? String {
                            
                            print("auth user: \(user) with passkey: \(passKey)")
                            log.enqueue("auth user: \(user) with passkey: \(passKey)")
                            
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
    //MARK UITextFieldDelegate
    @objc func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}





