//
//  MapViewController.swift
//  iOsmo
//
//  Created by Alexey Sirotkin on 23.08.16.
//  Copyright © 2015 Olga Grineva, © 2016 Alexey Sirotkin. All rights reserved.
//

import UIKit
import Mapbox


class MapViewController: UIViewController, UIActionSheetDelegate, MGLMapViewDelegate {
    
    var isTracked = true
    
    @IBOutlet weak var mapView: MGLMapView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMapView()
        setupLocationTrackingSettings()
        

        // Do any additional setup after loading the view.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func locateClick(sender: AnyObject) {
        if let location = mapView.userLocation?.location {
            mapView.setCenterCoordinate(location.coordinate, animated: true)
        }
    }
    
    @IBAction func changeTrackingModeClick(sender: AnyObject) {
        
        isTracked = !isTracked
        if isTracked {
            sender.setImage(UIImage(named: "unlock-25"), forState: UIControlState.Normal)
        } else {
            sender.setImage(UIImage(named: "lock-25"), forState: UIControlState.Normal)
        }
        setupLocationTrackingSettings()
    }
    
    func setupLocationTrackingSettings()
    {
        
        let trackingMode: MGLUserTrackingMode = (isTracked) ? MGLUserTrackingMode.Follow : MGLUserTrackingMode.None
        mapView.setUserTrackingMode(trackingMode, animated: true)
        
    }
    
    func setupMapView(){
        self.mapView.delegate = self
        self.mapView.showsUserLocation = true
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
