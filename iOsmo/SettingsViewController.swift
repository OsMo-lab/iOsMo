//
//  SettingsViewController.swift
//  iOsmo
//
//  Created by Olga Grineva on 10/01/15.
//  Modified by Alexey Sirotkin on 05/09/16.
//  Copyright (c) 2015 Olga Grineva, 2016 Alexey Sirotkin. All rights reserved.
//

import UIKit

class SettingsViewController: UIViewController, UITextFieldDelegate {

    var connectionManager = ConnectionManager.sharedConnectionManager
    var groupManager = GroupManager.sharedGroupManager
    
    var clickCount = 0;
    let MIN_SEND_TIME = 0;
    let MIN_LOC_DISTANCE = 0;
    
    
    @IBOutlet weak var awakeModeSwitcher: UISwitch!
    @IBOutlet weak var resetAuthSwitcher: UISwitch!
    @IBOutlet weak var longNamesSwitcher: UISwitch!
    @IBOutlet weak var distanceTextField: UITextField!
    @IBOutlet weak var locTimeTextField: UITextField!
    @IBOutlet weak var mapStyleButton: UIButton!
    
    @IBAction func AwakeModeChanged(_ sender: AnyObject) {
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
            if connectionManager.sessionOpened {
                alert(NSLocalizedString("Error on logout", comment:"Alert title for Error on logout"), message: NSLocalizedString("Stop current trip, before logout", comment:"Stop current trip, before logout"))
                self.resetAuthSwitcher.isOn = false
            } else {
                SettingsManager.clearKeys()
                connectionManager.closeConnection()
                connectionManager.connect()
            }
        }
    }
    
    
    
    @IBAction func LongNamesChanged(_ sender: AnyObject) {
        SettingsManager.setKey(longNamesSwitcher.isOn ? "1" : "0", forKey: SettingKeys.longNames)
    }
    
    @IBAction func textFieldEnter(_sender: UITextField){
        _sender.becomeFirstResponder()
    }

    func textFieldShouldReturn(_ textField: UITextField) -> Bool {
        textField.resignFirstResponder();
        return true;
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if let longNames = SettingsManager.getKey(SettingKeys.longNames) {
            longNamesSwitcher.setOn(longNames.boolValue, animated: false)
        }
        
        if let device = SettingsManager.getKey(SettingKeys.device) {
            if device.length > 0 {
                resetAuthSwitcher.setOn(false, animated: false)
            }
        }
        
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
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

}
