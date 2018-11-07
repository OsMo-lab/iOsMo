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
    let MIN_SEND_TIME = 4;
    let MIN_LOC_DISTANCE = 0;
    
    
    @IBOutlet weak var awakeModeSwitcher: UISwitch!
    @IBOutlet weak var resetAuthSwitcher: UISwitch!
    @IBOutlet weak var showTracksSwitcher: UISwitch!
    @IBOutlet weak var longNamesSwitcher: UISwitch!
    @IBOutlet weak var intervalTextField: UITextField!
    @IBOutlet weak var distanceTextField: UITextField!
    @IBOutlet weak var locTimeTextField: UITextField!
    @IBOutlet weak var mapStyleButton: UIButton!
    

    
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
    
    @IBAction func ShowTracksChanged(_ sender: AnyObject) {
        SettingsManager.setKey(showTracksSwitcher.isOn ? "1" : "0", forKey: SettingKeys.showTracks)
    }
    
    @IBAction func LongNamesChanged(_ sender: AnyObject) {
        SettingsManager.setKey(longNamesSwitcher.isOn ? "1" : "0", forKey: SettingKeys.longNames)
    }
    
    @IBAction func textFieldEnter(_sender: UITextField){
        _sender.becomeFirstResponder()
    }
    
    @IBAction func textFieldShouldEndEditing(_ textField: UITextField){
        if var value: Int = Int(textField.text!) {
            if textField == intervalTextField {
                //Требуется остановить - заново запустить трекинг, для активизации введенного значения
                if (value < MIN_SEND_TIME) {
                    value = MIN_SEND_TIME
                } else if (value > 60) {
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
            }
            textField.resignFirstResponder()
            
        }
        
        
    }
    
    @IBAction func SelectMapStyle(_ sender: UIButton) {
        let myAlert: UIAlertController = UIAlertController(title: title, message: NSLocalizedString("Map style", comment: "Select map style"), preferredStyle: .alert)
        var style:Int32 = 0
        
        func handler(_ act:UIAlertAction!) {
            var mapStyle: Int32;
            
            switch act.title! {
            case "Hot OSM":
                mapStyle = TileSource.Hotosm.rawValue
            case "MTB":
                mapStyle = TileSource.Mtb.rawValue
            case "Sputnik":
                mapStyle = TileSource.Sputnik.rawValue
            default:
                mapStyle = TileSource.Mapnik.rawValue

            }
            self.mapStyleButton.setTitle(act.title, for: .normal)
            SettingsManager.setKey("\(mapStyle)" as NSString, forKey: SettingKeys.tileSource)

        }
        
        while (style < TileSource.SOURCES_COUNT.rawValue) {
            let title = tileSourceName(style);
            if (title != "") {
                myAlert.addAction(UIAlertAction(title: title, style: .default, handler: handler))
            }
            style += 1;
            
        }

        self.present(myAlert, animated: true, completion: nil)
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
        if let showTracks = SettingsManager.getKey(SettingKeys.showTracks) {
            showTracksSwitcher.setOn(showTracks.boolValue, animated: false)
        }
        if let longNames = SettingsManager.getKey(SettingKeys.longNames) {
            longNamesSwitcher.setOn(longNames.boolValue, animated: false)
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
        var mapTitle = "Mapnik"
        if let mapStyle = SettingsManager.getKey(SettingKeys.tileSource)?.intValue{
            mapTitle = tileSourceName(mapStyle)
        }
        mapStyleButton.setTitle(mapTitle, for: UIControlState.normal)
        
        //intervalTextField.becomeFirstResponder()
        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func tileSourceName(_ source: Int32) -> String {
        var mapTitle = ""
        switch source {
            case TileSource.Hotosm.rawValue:
                mapTitle = "Hot OSM"
            case TileSource.Mtb.rawValue:
                mapTitle  = "MTB"
            case TileSource.Sputnik.rawValue:
                mapTitle  = "Sputnik"
            default:
                mapTitle  = "Mapnik"
        }
        return mapTitle
        
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
