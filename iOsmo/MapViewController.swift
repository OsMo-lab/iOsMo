//
//  MapViewController.swift
//  iOsmo
//
//  Created by Alexey Sirotkin on 23.08.16.
//  Copyright © 2015 Olga Grineva, © 2017 Alexey Sirotkin. All rights reserved.
//

import UIKit
import Mapbox

// MGLAnnotation protocol reimplementation
class OSMOAnnotation: NSObject, MGLAnnotation {
    
    // As a reimplementation of the MGLAnnotation protocol, we have to add mutable coordinate and (sub)title properties ourselves.
    var coordinate: CLLocationCoordinate2D
    var title: String?

    // Custom properties that we will use to customize the annotation's image.
    var image: UIImage?
    var objId: String?
    
    init(coordinate: CLLocationCoordinate2D, title: String?, objId: String) {
        self.coordinate = coordinate
        self.title = title
        self.objId = objId
    }
}
// MGLAnnotationView subclass
class OSMOAnnotationView: MGLAnnotationView {
    override func layoutSubviews() {
        super.layoutSubviews()
        
        // Force the annotation view to maintain a constant size when the map is tilted.
        scalesWithViewingDistance = false
        
        // Use CALayer’s corner radius to turn this view into a circle.
        layer.cornerRadius = frame.width / 2
        layer.borderWidth = 3
        layer.borderColor = UIColor.white.cgColor
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        
        // Animate the border width in/out, creating an iris effect.
        let animation = CABasicAnimation(keyPath: "borderWidth")
        animation.duration = 0.1
        layer.borderWidth = selected ? frame.width / 4 : 3
        layer.add(animation, forKey: "borderWidth")
    }
}
// MGLPolyline subclass
class CustomPolyline: MGLPolyline {
    // Because this is a subclass of MGLPolyline, there is no need to redeclare its properties.
    
    // Custom property that we will use when drawing the polyline.
    var color: UIColor?
}

class MapViewController: UIViewController, UIActionSheetDelegate, MGLMapViewDelegate {
    
    required init(coder aDecoder: NSCoder) {

        connectionManager = ConnectionManager.sharedConnectionManager
        groupManager = GroupManager.sharedGroupManager
        
        super.init(coder: aDecoder)!
    }
    
    var isTracked = true
    let connectionManager: ConnectionManager
    let groupManager: GroupManager
    var onMapNow = [String]()
    
    var onMonitoringGroupsUpdated: ObserverSetEntry<[UserGroupCoordinate]>?
    var inGroup: [Group]?
    var selectedGroupIndex: Int?
    
    var pointAnnotations = [OSMOAnnotation]()

    @IBOutlet weak var mapView: MGLMapView!
    

    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupMapView()
        setupLocationTrackingSettings()
        

        // Do any additional setup after loading the view.
    }
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        self.connectionManager.activatePoolGroups(1)
        
        groupManager.updateGroupsOnMap([1])
        self.onMonitoringGroupsUpdated = groupManager.monitoringGroupsUpdated.add{
            
            for coord in $0 {
                
                self.drawPeoples(location: coord)
            }
        }

    }
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    @IBAction func locateClick(sender: AnyObject) {
        if let location = mapView.userLocation?.location {
            mapView.setCenter(location.coordinate, animated: true)
        }
    }

    @IBAction func changeTrackingModeClick(sender: AnyObject) {
        isTracked = !isTracked
        if isTracked {
            sender.setImage(UIImage(named: "unlock-25"), for: UIControlState.normal)
        } else {
            sender.setImage(UIImage(named: "lock-25"), for: UIControlState.normal)
        }
        setupLocationTrackingSettings()
    }
    
    @IBAction func selectGroupsClick(_ sender: AnyObject) {
        
        //let selectedGroupName = (selectedGroupIndex != nil) ? inGroup?[selectedGroupIndex!].name : nil
        
        let actionSheet = UIActionSheet(title: "select group", delegate: self, cancelButtonTitle: "cancel", destructiveButtonTitle: nil)
        
        if selectedGroupIndex != nil {
            
            actionSheet.destructiveButtonIndex = selectedGroupIndex! + 1
        }
        
        if let groups = inGroup {
            
            for group in groups{
                
                actionSheet.addButton(withTitle: group.name)
            }
            
            if selectedGroupIndex != nil { actionSheet.addButton(withTitle: "clear all") }
        }
        
        //actionSheet.showInView(self.mapView)
    }
    
    func setupLocationTrackingSettings()
    {
        let trackingMode: MGLUserTrackingMode = (isTracked) ? MGLUserTrackingMode.follow : MGLUserTrackingMode.none
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
    
    func clearPeople(_ people: String){
        var idx = 0;
        
        for ann in self.pointAnnotations {
            
            if ann.title == people {
                self.mapView.removeAnnotation(ann as MGLAnnotation);
                self.pointAnnotations.remove(at: idx)

                break;
                
            }
            idx = idx + 1;
        }
    }
    
    func drawPeoples(location: UserGroupCoordinate){
        
        let clLocation = CLLocationCoordinate2D(latitude: location.location.lat, longitude: location.location.lon)
        if (self.mapView) != nil {
            if let user = groupManager.getUser(location.groupId, user: location.userId){
                let userName = user.name
                var annVisible = false;
                
                for ann in self.pointAnnotations {
                    if ann.objId == "u\(location.userId)" {
                        ann.coordinate = clLocation;
                        annVisible = true;
                        break;

                    }
                    
                }
                if !annVisible {
                    let annotation = OSMOAnnotation(coordinate: clLocation, title: userName, objId: "u\(location.userId)");
                    self.pointAnnotations.append(annotation)
                    self.mapView.addAnnotation(annotation)
                }
                //clearPeople("\(user.name)")
            }
        }
    }
    
    
    func actionSheet(_ actionSheet: UIActionSheet, clickedButtonAt buttonIndex: Int) {
        
        if actionSheet.buttonTitle(at: buttonIndex) == "clear all" {
            self.selectedGroupIndex = nil
            
            groupManager.updateGroupsOnMap([])
            
            if self.onMonitoringGroupsUpdated != nil {
                
                groupManager.monitoringGroupsUpdated.remove(self.onMonitoringGroupsUpdated!)
                self.onMonitoringGroupsUpdated = nil
            }
            for p in onMapNow {
                clearPeople("\(p)")
            }
            
            return
        }
        
        if buttonIndex != actionSheet.cancelButtonIndex {
            if let group = inGroup?[buttonIndex - 1]  {
                
                let intValue = Int (group.id);
                
                groupManager.updateGroupsOnMap([intValue!])
                self.onMonitoringGroupsUpdated = groupManager.monitoringGroupsUpdated.add{
                    
                    for coord in $0 {
                        
                        self.drawPeoples(location: coord)
                    }
                }
                
                for p in onMapNow {
                    clearPeople("\(p)")
                }
                
                self.selectedGroupIndex = buttonIndex - 1
                
            }
        }
        
        
    }
    
    func mapView(_ mapView: MGLMapView, viewFor annotation: MGLAnnotation) -> MGLAnnotationView? {
        // This example is only concerned with point annotations.
        guard annotation is OSMOAnnotation else {
            return nil
        }
        
        // Use the point annotation’s longitude value (as a string) as the reuse identifier for its view.
        let reuseIdentifier = "user"
        
        // For better performance, always try to reuse existing annotations.
        var annotationView = mapView.dequeueReusableAnnotationView(withIdentifier: reuseIdentifier)
        
        // If there’s no reusable annotation view available, initialize a new one.
        if annotationView == nil {
            annotationView = OSMOAnnotationView(reuseIdentifier: reuseIdentifier)
            annotationView!.frame = CGRect(x: 0, y: 0, width: 20, height: 20)
            
            // Set the annotation view’s background color to a value determined by its longitude.
            //let hue = CGFloat(annotation.coordinate.longitude) / 100
            //annotationView!.backgroundColor = UIColor(hue: hue, saturation: 0.5, brightness: 1, alpha: 1)
            annotationView!.backgroundColor = UIColor(colorLiteralRed: 0.31, green: 0.68, blue: 0.41, alpha: 1)
        }
        
        return annotationView
    }
    
}
