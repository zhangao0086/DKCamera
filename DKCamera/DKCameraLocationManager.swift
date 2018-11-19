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
    
    public func gpsMetadataForLatestLocation() -> [String: Any]? {
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
        
        var gpsMetadata = [CFString: Any]()
        
        let altitudeRef = Int(location.altitude < 0.0 ? 1 : 0)
        let latitudeRef = location.coordinate.latitude < 0.0 ? "S" : "N"
        let longitudeRef = location.coordinate.longitude < 0.0 ? "W" : "E"
        
        // GPS metadata
        gpsMetadata[(kCGImagePropertyGPSLatitude)] = location.coordinate.latitude
        gpsMetadata[(kCGImagePropertyGPSLongitude)] = location.coordinate.longitude
        gpsMetadata[(kCGImagePropertyGPSLatitudeRef)] = latitudeRef
        gpsMetadata[(kCGImagePropertyGPSLongitudeRef)] = longitudeRef
        gpsMetadata[(kCGImagePropertyGPSAltitude)] = location.altitude
        gpsMetadata[(kCGImagePropertyGPSAltitudeRef)] = altitudeRef
        gpsMetadata[(kCGImagePropertyGPSTimeStamp)] = toISOTime(location.timestamp)
        gpsMetadata[(kCGImagePropertyGPSDateStamp)] = toISODate(location.timestamp)
        gpsMetadata[(kCGImagePropertyGPSVersion)] = "2.2.0.0"
        
        if let heading = self.locationManager.heading {
            gpsMetadata[(kCGImagePropertyGPSImgDirection)] = heading.trueHeading
            gpsMetadata[(kCGImagePropertyGPSImgDirectionRef)] = "T"
        }
        
        return gpsMetadata as [String : Any]
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
