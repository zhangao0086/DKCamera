//
//  DKCameraLocationManager.swift
//  DKCameraDemo
//
//  Created by Ao Zhang on 2018/11/19.
//  Copyright © 2018 ZhangAo. All rights reserved.
//

import Foundation
import CoreLocation
import ImageIO

@objc
public class DKCameraLocationManager: NSObject, CLLocationManagerDelegate {
    
    public var latestLocation: CLLocation?
    
    private lazy var locationManager: CLLocationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyBest
        locationManager.requestWhenInUseAuthorization()
        
        return locationManager
    }()
    
    private var enable = false
    
    public func startUpdatingLocation() {
        self.enable = true
        self.locationManager.startUpdatingLocation()
    }
    
    public func stopUpdatingLocation() {
        self.enable = false
        self.locationManager.stopUpdatingLocation()
    }
    
    public func gpsMetadataForLatestLocation() -> [String: AnyObject]? {
        guard let location = self.latestLocation else { return nil }
        
        func toISODate(_ date: Date) -> String {
            let f = DateFormatter()
            f.timeZone = TimeZone(abbreviation: "UTC")
            f.dateFormat = "yyyy:MM:dd"
            return f.string(from: date)
        }
        
        func toISOTime(_ date: Date) -> String {
            let f = DateFormatter()
            f.timeZone = TimeZone(abbreviation: "UTC")
            f.dateFormat = "HH:mm:ss.SSSSSS"
            return f.string(from: date)
        }
        
        var gpsMetadata = [String: AnyObject]()
        
        let altitudeRef = Int(location.altitude < 0.0 ? 1 : 0)
        let latitudeRef = location.coordinate.latitude < 0.0 ? "S" : "N"
        let longitudeRef = location.coordinate.longitude < 0.0 ? "W" : "E"
        
        // GPS metadata
        gpsMetadata[(kCGImagePropertyGPSLatitude as String)] = location.coordinate.latitude as AnyObject
        gpsMetadata[(kCGImagePropertyGPSLongitude as String)] = location.coordinate.longitude as AnyObject
        gpsMetadata[(kCGImagePropertyGPSLatitudeRef as String)] = latitudeRef as AnyObject
        gpsMetadata[(kCGImagePropertyGPSLongitudeRef as String)] = longitudeRef as AnyObject
        gpsMetadata[(kCGImagePropertyGPSAltitude as String)] = location.altitude as AnyObject
        gpsMetadata[(kCGImagePropertyGPSAltitudeRef as String)] = altitudeRef as AnyObject
        gpsMetadata[(kCGImagePropertyGPSTimeStamp as String)] = toISOTime(location.timestamp) as AnyObject
        gpsMetadata[(kCGImagePropertyGPSDateStamp as String)] = toISODate(location.timestamp) as AnyObject
        gpsMetadata[(kCGImagePropertyGPSVersion as String)] = "2.2.0.0" as AnyObject
        
        if let heading = self.locationManager.heading {
            gpsMetadata[(kCGImagePropertyGPSImgDirection as String)] = heading.trueHeading as AnyObject
            gpsMetadata[(kCGImagePropertyGPSImgDirectionRef as String)] = "T" as AnyObject
        }
        
        return gpsMetadata
    }
    
    // MARK: - CLLocationManagerDelegate
    
    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        self.latestLocation = locations.sorted { $0.horizontalAccuracy < $1.horizontalAccuracy }.first
    }
    
    public func locationManager(_ manager: CLLocationManager, didChangeAuthorization status: CLAuthorizationStatus) {
        switch status {
        case .authorizedAlways: fallthrough
        case .authorizedWhenInUse:
            if self.enable {
                self.locationManager.startUpdatingLocation()
            }
        default:
            self.locationManager.stopUpdatingLocation()
        }
    }
}
