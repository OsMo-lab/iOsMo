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
    
    @IBOutlet weak var awakeModeSwitcher: UISwitch!
    @IBOutlet weak var resetAuthSwitcher: UISwitch!
    @IBOutlet weak var intervalTextField: UITextField!
    
    @IBAction func AwakeModeChanged(_ sender: AnyObject) {
    
        SettingsManager.setKey(self.awakeModeSwitcher.isOn ? "1" : "0", forKey: SettingKeys.isStayAwake)
        
        UIApplication.shared.isIdleTimerDisabled = awakeModeSwitcher.isOn
    
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
        
        //Требуется остановить - заново запустить трекинг, для активизации введенного значения
        var sendTime: Double = Double(textField.text!)!;
        if (sendTime < 5) {
            sendTime = 5
        }else if (sendTime > 60) {
            sendTime = 60
        }
        SettingsManager.setKey(String(sendTime) as NSString, forKey: SettingKeys.sendTime)
        intervalTextField.resignFirstResponder()
    
    }
    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        intervalTextField.resignFirstResponder();
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
                sendTime = "5"
            }
            intervalTextField.text = sendTime as String
        }
        //intervalTextField.becomeFirstResponder()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
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

}
