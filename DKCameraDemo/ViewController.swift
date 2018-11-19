//
//  ViewController.swift
//  DKCameraDemo
//
//  Created by ZhangAo on 15/8/30.
//  Copyright (c) 2015年 ZhangAo. All rights reserved.
//

import UIKit
import AVFoundation

class ViewController: UIViewController {

    @IBOutlet var imageView: UIImageView?
    lazy var faceLayer: CALayer = {
        let faceLayer = CALayer()
        faceLayer.borderColor = UIColor.red.cgColor
        faceLayer.borderWidth = 1
        
        UIApplication.shared.keyWindow?.rootViewController?.presentedViewController?.view.layer.addSublayer(faceLayer)
        return faceLayer
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        // Do any additional setup after loading the view, typically from a nib.
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }

    @IBAction func capture() {        
        let camera = DKCamera()
//        camera.containsGPSInMetadata = true
//		  camera.showsCameraControls = false
//        camera.defaultCaptureDevice = .front
//        camera.onFaceDetection = { [unowned self, camera] (faces: [AVMetadataFaceObject]) in
//            if let face = faces.first {
//                DispatchQueue.main.async {
//                    let bounds = face.realBounds(inCamera: camera)
//                    self.faceLayer.position = bounds.origin
//                    self.faceLayer.bounds.size = bounds.size
//                }
//            }
//        }

        camera.didCancel = { () in
            print("didCancel")
            
            self.dismiss(animated: true, completion: nil)
        }
        
        camera.didFinishCapturingImage = { (image: UIImage?, metadata: [AnyHashable : Any]?) in
            print("didFinishCapturingImage")
            
            self.dismiss(animated: true, completion: nil)
            
            self.imageView?.image = image
        }
        self.present(camera, animated: true, completion: nil)
    }
	
}

