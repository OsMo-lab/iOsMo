//
//  MapZenViewController.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 25.10.17.
//  Copyright © 2017 Alexey Sirotkin. All rights reserved.
//

import Foundation
import Mapzen_ios_sdk
import TangramMap
import FirebaseAnalytics
import CoreLocation

class MapZenViewController: MZMapViewController {
    required init(coder aDecoder: NSCoder) {
        print("mapBox init")
        connectionManager = ConnectionManager.sharedConnectionManager
        groupManager = GroupManager.sharedGroupManager
        
        super.init(coder: aDecoder)!
    }
    
    var isTracked = true
    let connectionManager: ConnectionManager
    let groupManager: GroupManager
    var onMapNow = [String]()
    
    var onMonitoringGroupsUpdated: ObserverSetEntry<[UserGroupCoordinate]>?
    var onUserLeave: ObserverSetEntry<User>?
    var selectedGroupIndex: Int?
    var trackedUser: String = ""

    var pointAnnotations = [PeliasMapkitAnnotation]()
    
    
    override func viewDidLoad() {
        super.viewDidLoad()
        print("MapZen viewDidLoad")
        // Do any additional setup after loading the view, typically from a nib.
        _ = try? loadStyleAsync(.cinnabar) { (style) in
            // the map is now ready for interaction
            
            _ = self.showCurrentLocation(true)
            _ = self.showFindMeButon(true)
            
            if let lat = SettingsManager.getKey(SettingKeys.lat)?.doubleValue, let lon = SettingsManager.getKey(SettingKeys.lon)?.doubleValue,let zoom = SettingsManager.getKey(SettingKeys.zoom)?.doubleValue {
                if ((lat != 0) && (lon != 0) && (zoom != 0)) {
                    self.position = TGGeoPointMake(lon,lat)
                    self.rotation = 0
                    self.zoom = Float(zoom)
                    self.tilt = 0
                }
            }
            self.onMonitoringGroupsUpdated = self.groupManager.monitoringGroupsUpdated.add{
                for coord in $0 {
                    DispatchQueue.main.async {
                        self.drawPeoples(location: coord)
                    }
                }
            }
            _ = self.groupManager.groupsUpdated.add{
                _ = $0
                _ = $1
                DispatchQueue.main.async {
                    self.updateGroupsOnMap(groups: self.groupManager.allGroups )
                }
            }
            _ = self.groupManager.groupListUpdated.add{
                let groups = $0
                DispatchQueue.main.async {
                    self.updateGroupsOnMap(groups: groups)
                }
            }
            _ = self.connectionManager.connectionRun.add{
                let theChange = $0.0
                
                if theChange {
                    DispatchQueue.main.async {
                        self.connectionManager.activatePoolGroups(1)
                    }
                }
            }
        }
    }
    
    override func viewWillAppear(_ animated:Bool) {
        super.viewWillAppear(animated)
        
        print("MapBox viewWillAppear")
        Analytics.logEvent("map_open", parameters: nil)
        
        if (groupManager.allGroups.count) > 0 {
            self.connectionManager.activatePoolGroups(1)
            
            groupManager.updateGroupsOnMap([1])
            
            self.updateGroupsOnMap(groups: groupManager.allGroups )
        }
    }

    
    override func viewWillDisappear(_ animated: Bool){
        super.viewWillDisappear(animated)
        print("MapZen viewWillDisappear")
        groupManager.updateGroupsOnMap([])

        SettingsManager.setKey("\(self.position.latitude)" as NSString, forKey: SettingKeys.lat)
        SettingsManager.setKey("\(self.position.longitude)" as NSString, forKey: SettingKeys.lon)
        SettingsManager.setKey("\(self.zoom)" as NSString, forKey: SettingKeys.zoom)
    }
    
    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    func updateGroupsOnMap(groups: [Group]) {
        print("updateGroupsOnMap")
        var curAnnotations = [String]()
        var curTracks = [String]()
        
        for group in groups{
            for user in group.users {
                if user.lat > -3000 && user.lon > -3000 {
                    let location = LocationModel(lat: user.lat, lon: user.lon)
                    let gid = Int(group.u)
                    let uid = Int(user.id)
                    let ugc: UserGroupCoordinate = UserGroupCoordinate(group: gid!, user: uid!,  location: location)
                    ugc.recent = false
                    self.drawPeoples(location: ugc)
                    curAnnotations.append("u\(uid!)")
                }
            }
            for point in group.points {
                drawPoint(point: point, group:group)
                curAnnotations.append("p\(point.u)")
            }
            for track in group.tracks {
                drawTrack(track: track)
                curTracks.append("t\(track.u)")
            }
        }
        var idx = 0;
        for ann in pointAnnotations {
            var delete = true;
            var annObjId = ann.data?["objId"] as? String
            if curAnnotations.count > 0 {
                for objId in curAnnotations {
                    if annObjId == objId {
                        delete = false;
                        break;
                    }
                }
            }
            
            if (delete == true) {
                
                if !(annObjId?.contains("wpt"))! {
                    do {
                        try self.remove(ann)
                    } catch {
      
                    }
                    pointAnnotations.remove(at: idx)
                    print("removing \(annObjId)")
                }
            } else {
                idx = idx + 1
            }
        }
        idx = 0;
        /*
        for ann in trackAnnotations {
            var delete = true;
            if curTracks.count > 0 {
                for objId in curTracks {
                    if annObjId == objId {
                        delete = false;
                        break;
                    }
                }
            }
            
            if (delete == true) {
                self.mapView.removeAnnotation(ann)
                trackAnnotations.remove(at: idx)
                print("removing \(ann.objId)")
            } else {
                idx = idx + 1
            }
        }
 */
    }
    
    func drawTrack(track:Track) {
        print ("MapBox drawTrack")
        /*
        if (self.mapView != nil) {
            if let xml = track.getTrackData() {
                let gpx = xml.children[0]
                for trk in gpx.children {
                    if trk.name == "trk" {
                        //var polylines = [OSMPolyline]()
                        
                        for trkseg in trk.children {
                            if trkseg.name == "trkseg" {
                                var coordinates = [CLLocationCoordinate2D]()
                                
                                for trkpt in trkseg.children {
                                    if trkpt.name == "trkpt" {
                                        let lat = atof(trkpt.attributes["lat"])
                                        let lon = atof(trkpt.attributes["lon"])
                                        coordinates.append(CLLocationCoordinate2D(latitude: lat, longitude: lon) )
                                    }
                                    
                                }
                                if coordinates.count > 0 {
                                    let polyline = OSMPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
                                    // Set the custom `color` property, later used in the `mapView:strokeColorForShapeAnnotation:` delegate method.
                                    polyline.color = track.color.hexColor.withAlphaComponent(0.8)
                                    polyline.title = track.name
                                    polyline.objId = "t\(track.u)"
                                    
                                    self.mapView.addAnnotation(polyline)
                                    self.trackAnnotations.append(polyline)
                                    
                                    //polylines.append(polyline)
                                }
                                
                            }
                            
                        }
                    }
                    if trk.name == "wpt" {
                        let lat = atof(trk.attributes["lat"])
                        let lon = atof(trk.attributes["lon"])
                        let name = trk["name"]?.text
                        let clLocation = CLLocationCoordinate2D(latitude: lat, longitude: lon)
                        let annotation = OSMOAnnotation(type:AnnotationType.point,  coordinate: clLocation, title: name, objId: "wpt\(track.u)");
                        annotation.subtitle = "Waypoint"
                        annotation.color = track.color
                        
                        self.pointAnnotations.append(annotation)
                        self.mapView.addAnnotation(annotation)
                        
                        
                    }
                    /*
                     let multiPolyline = OSMMultiPolyline(polylines: polylines)
                     multiPolyline.objId = "t\(track.u)"
                     multiPolyline.title = track.name
                     let source = MGLShapeSource(identifier: multiPolyline.objId, shapes: polylines, options: nil)
                     mapView.style?.addSource(source)
                     
                     let layer = MGLFillStyleLayer(identifier: multiPolyline.objId, source: source)
                     
                     layer.fillColor = MGLStyleValue<UIColor>(rawValue: track.color.hexColor.withAlphaComponent(0.8))
                     layer.fillOutlineColor = MGLStyleValue<UIColor>(rawValue:track.color.hexColor.withAlphaComponent(0.8))
                     mapView.style?.addLayer(layer)
                     
                     self.trackAnnotations.append(multiPolyline)
                     */
                }
                
            }
            
        }
 */
    }
    func drawPoint(point: Point, group: Group){
        print("MapBox drawPoint")
        let clLocation = CLLocationCoordinate2D(latitude: point.lat, longitude: point.lon)
        if (self.mapView) != nil {
            var annVisible = false;
            for ann in self.pointAnnotations {
                let objId = ann.data?["objId"] as? String
                if objId == "p\(point.u)" {
                    //ann.coordinate = clLocation
                    annVisible = true;
                    break;
                }
            }
            if !annVisible {
                var pointDictionary = [String:AnyObject]()
                pointDictionary["objId"] = "p\(point.u)" as AnyObject?
                let annotation = PeliasMapkitAnnotation(coordinate: clLocation, title: point.name, subtitle: "\(group.name)\n\(point.descr)", data: pointDictionary)
                //annotation.color = point.color
                //annotation.subtitle = "\(group.name)\n\(point.descr)"
                self.pointAnnotations.append(annotation)
                do {
                    try self.add([annotation])
                } catch {
                    
                }
            }
        }
    }
    
    func drawPeoples(location: UserGroupCoordinate){
        print("MapBox drawPeoples")
        let clLocation = CLLocationCoordinate2D(latitude: location.location.lat, longitude: location.location.lon)
        if (self.mapView) != nil {
            if let user = groupManager.getUser(location.groupId, user: location.userId){
                let userName = user.name
                var annVisible = false;
                for ann in self.pointAnnotations {
                    let annObjId = ann.data?["objId"] as? String
                    if annObjId == "u\(location.userId)" {
                        /*
                        if ann.polyline == nil {
                            var coordinates = [ann.coordinate, clLocation]
                            
                            let polyline = OSMPolyline(coordinates: &coordinates, count: UInt(coordinates.count))
                            
                            // Set the custom `color` property, later used in the `mapView:strokeColorForShapeAnnotation:` delegate method.
                            polyline.color = user.color.hexColor.withAlphaComponent(0.8)
                            
                            // Add the polyline to the map. Note that this method name is singular.
                            mapView.addAnnotation(polyline)
                            ann.polyline = polyline;
                            
                        } else {
                            //Не добавляем в конец трека координаты пользователя из GROUP.users
                            if location.recent == true {
                                ann.polyline?.appendCoordinates([clLocation], count: 1)
                                if self.trackedUser == ann.objId {
                                    self.mapView.setCenter(clLocation, animated: true)
                                }
                            }
                        }
                        ann.coordinate = clLocation;
 
                        ann.labelColor = "#000000";
 */
                        annVisible = true;
                        break;
                    }
                }
                if !annVisible {
                    var pointDictionary = [String:AnyObject]()
                    pointDictionary["objId"] = "u\(location.userId)" as AnyObject?
                    let annotation = PeliasMapkitAnnotation(coordinate: clLocation, title: userName, subtitle: "", data: pointDictionary)
                    
               
                    /*
                    annotation.color = user.color
                    if location.recent == false {
                        annotation.labelColor = "#AAAAAA"
                    }
 */
                    self.pointAnnotations.append(annotation)
                    do {
                        try self.add([annotation])
                    } catch {
                        
                    }
                    print("add u\(location.userId)")
                }
            }
        }
    }
}
