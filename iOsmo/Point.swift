//
//  Point.swift
//  iOsMo
//
//  Created by Alexey Sirotkin on 03.03.17.
//  Copyright © 2017 Alexey Sirotkin. All rights reserved.
//

import Foundation
import MapKit


public class Point: NSObject, MKAnnotation {
    var u: Int
    var groupId: Int = 0
    var lat: Double
    var lon: Double
    var descr: String = ""
    var color: String = "#ffffff"
    var name: String = ""
    var url: String = ""
    var start: Date?
    var finish: Date?
    var time: Date?
    
    var mapId: String! = ""
    
    public var subtitle: String?   //MKAnnonation protocol

    init(json: Dictionary<String, AnyObject>) {
        self.u = json["u"] as? Int ?? Int(json["u"] as? String ?? "0")!
        self.lat = json["lat"] as? Double ?? atof(json["lat"] as? String ?? "")
        self.lon = json["lon"] as? Double ?? atof(json["lon"] as? String ?? "")
        self.name = json["name"] as? String ?? ""
        self.descr = json["description"] as? String ?? ""
        self.url = json["url"] as? String ?? ""
        self.color = json["color"] as? String ?? "#ffffff"
        self.mapId = "p-\(groupId)-\(u)"
        self.subtitle = self.descr
        
        let uTime = (json["time"] as? Double) ?? atof(json["time"] as? String ?? "0")
        if uTime > 0 {
            self.time = Date(timeIntervalSince1970: uTime)
        }
        let uFinish = (json["finish"] as? Double) ?? atof(json["finish"] as? String ?? "0")
        if uFinish > 0 {
            self.finish = Date(timeIntervalSince1970: uFinish)
        }
        let uStart = (json["start"] as? Double) ?? atof(json["start"] as? String ?? "0")
        if uStart > 0 {
            self.start = Date(timeIntervalSince1970: uStart)
        }
    }
    
    public static func == (left: Point, right: Point) -> Bool {
        return left.u == right.u
    }
    
    
    //MKAnnonation protocol
    open var title: String? {
        return name;
    }
    
    
    open var coordinate : CLLocationCoordinate2D {
        return CLLocationCoordinate2D(latitude: lat, longitude: lon);
    }
}

