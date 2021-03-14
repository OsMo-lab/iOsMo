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

open class AuthViewController: UIViewController, UITextViewDelegate, UITextFieldDelegate {
    let log = LogQueue.sharedLogQueue
    
    @IBOutlet weak var emailField: UITextField!
    @IBOutlet weak var passField: UITextField!
    @IBOutlet weak var nickField: UITextField!
    @IBOutlet weak var pass2Field: UITextField!
    @IBOutlet weak var signButton: UIButton!
    @IBOutlet weak var actButton: UIButton!
    @IBOutlet weak var forgotButton: UIButton!
    
    @IBOutlet weak var signLabel: UILabel!
    @IBOutlet weak var registerView: UIView!
    @IBOutlet weak var signToRegConstraint: NSLayoutConstraint!
    @IBOutlet weak var signToPassConstraint: NSLayoutConstraint!

    
    var signAction: SignActions = SignActions.SignIn
    @IBAction func OnCancel(_ sender: AnyObject) {
        
        delegate?.loginCancelled(self)
    }
    
    var delegate: AuthResultProtocol?    
    
    override open func viewDidLoad() {
        super.viewDidLoad()
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
        let url = URL(string: signAction == SignActions.SignIn ? "https://\(URLs.osmoDomain)/signin?" : "https://api2.osmo.mobi/signup?")
        let session = URLSession.shared;
        var urlReq = URLRequest(url: url!);
        var requestBody:String = "key=\(device)&email=\(emailField.text!)&password=\(passField.text!)"
        if (signAction == SignActions.SignUp) {
            requestBody = "\(requestBody)&nick=\(nickField.text!)"
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
        UIApplication.shared.open(URL(string: "https://osmo.mobi/forgot?utm_campaign=OsMo.App&utm_source=iOsMo&utm_term=forgot")!, options: [:], completionHandler: nil)
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

    //MARK UITextFieldDelegate
    public func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder()
        return true
    }
}





