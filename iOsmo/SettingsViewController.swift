//
//  SettingsViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 10/01/15.
//  Modified by Alexey Sirotkin on 05/09/16.
//  Copyright (c) 2015 Olga Grineva, 2016 Alexey Sirotkin. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController ,UITextFieldDelegate {

    var connectionManager = ConnectionManager.sharedConnectionManager
    var clickCount = 0;
    let MIN_SEND_TIME = 5;
    let MIN_LOC_TIME = 4;
    let MIN_LOC_DISTANCE = 10;
    
    
    @IBOutlet weak var awakeModeSwitcher: UISwitch!
    @IBOutlet weak var resetAuthSwitcher: UISwitch!
    @IBOutlet weak var intervalTextField: UITextField!
    @IBOutlet weak var distanceTextField: UITextField!
    @IBOutlet weak var locTimeTextField: UITextField!

    
    @IBAction func AwakeModeChanged(_ sender: AnyObject) {
    
        SettingsManager.setKey(self.awakeModeSwitcher.isOn ? "1" : "0", forKey: SettingKeys.isStayAwake)
        
        UIApplication.shared.isIdleTimerDisabled = awakeModeSwitcher.isOn
        if (awakeModeSwitcher.isOn) {
            clickCount += 1;
            if (clickCount == 7) {
                SettingsManager.setKey("enable", forKey: SettingKeys.logView)
                self.alert(NSLocalizedString("LogView unlocked", comment:"LogView unlocked"),message:NSLocalizedString("Restart iOsMo", comment:"Restart iOsMo"))
            }
        }
    }
    
    /*Сброс авторизации устройства*/
    @IBAction func ResetModeChanged(_ sender: AnyObject) {
        if self.resetAuthSwitcher.isOn {
            SettingsManager.setKey("", forKey: SettingKeys.device)
            SettingsManager.setKey("", forKey: SettingKeys.user)
            SettingsManager.setKey("", forKey: SettingKeys.auth)
            connectionManager.connect()
        }
    }
    
    @IBAction func textFieldEnter(_sender: UITextField){
        _sender.becomeFirstResponder()
    }
    
    @IBAction func textFieldShouldEndEditing(_ textField: UITextField){
        var value: Int = Int(textField.text!)!;
        
        if textField == intervalTextField {
            //Требуется остановить - заново запустить трекинг, для активизации введенного значения
            if (value < MIN_SEND_TIME) {
                value = MIN_SEND_TIME
            }else if (value > 60) {
                value = 60
            }
            SettingsManager.setKey(String(value) as NSString, forKey: SettingKeys.sendTime)
        
        } else if textField == distanceTextField {
            if (value < MIN_LOC_DISTANCE) {
                value = MIN_LOC_DISTANCE
            }else if (value > 1000) {
                value = 1000
            }
            SettingsManager.setKey(String(value) as NSString, forKey: SettingKeys.locDistance)
        } else if textField == locTimeTextField {
            if (value < MIN_LOC_TIME) {
                value = MIN_LOC_TIME
            }else if (value > 120) {
                value = 120
            }
            SettingsManager.setKey(String(value) as NSString, forKey: SettingKeys.locInterval)
        }
        textField.resignFirstResponder()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder();
        return true;
    }
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let isStayAwake = SettingsManager.getKey(SettingKeys.isStayAwake) {
            awakeModeSwitcher.setOn(isStayAwake.boolValue, animated: false)
        }
        
        if let device = SettingsManager.getKey(SettingKeys.device) {
            if device.length > 0 {
                resetAuthSwitcher.setOn(false, animated: false)
            }
        }
        
        if var sendTime = SettingsManager.getKey(SettingKeys.sendTime) {
            if sendTime.length == 0 {
                sendTime = String(MIN_SEND_TIME) as NSString
            }
            intervalTextField.text = sendTime as String
        }
        if var locDistance = SettingsManager.getKey(SettingKeys.locDistance) {
            if locDistance.length == 0 {
                locDistance = String(MIN_LOC_DISTANCE) as NSString
            }
            distanceTextField.text = locDistance as String
        }
        if var locInterval = SettingsManager.getKey(SettingKeys.locInterval) {
            if locInterval.length == 0 {
                locInterval = String(MIN_LOC_TIME) as NSString
            }
            locTimeTextField.text = locInterval as String
        }
        //intervalTextField.becomeFirstResponder()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func alert(_ title: String, message: String) {
        if let getModernAlert: AnyClass = NSClassFromString("UIAlertController") { // iOS 8
            let myAlert: UIAlertController = UIAlertController(title: title, message: message, preferredStyle: .alert)
            myAlert.addAction(UIAlertAction(title: NSLocalizedString("OK", comment:"OK"), style: .default, handler: nil))
            self.present(myAlert, animated: true, completion: nil)
        } else { // iOS 7
            let alert: UIAlertView = UIAlertView()
            alert.delegate = self
            
            alert.title = title
            alert.message = message
            alert.addButton(withTitle: NSLocalizedString("OK", comment:"OK"))
            
            alert.show()
        }
    }

    /*
    // MARK: - Navigation

    // In a storyboard-based application, you will often want to do a little preparation before navigation
    override func prepareForSegue(segue: UIStoryboardSegue, sender: AnyObject?) {
        // Get the new view controller using segue.destinationViewController.
        // Pass the selected object to the new view controller.
    }
    */

}
