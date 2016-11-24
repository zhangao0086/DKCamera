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
//		camera.showsCameraControls = false
//        camera.defaultCaptureDevice = .front
//        camera.onFaceDetection = { (faces: [AVMetadataFaceObject]) in
//            
//        }
        camera.didCancel = { () in
            print("didCancel")
            
            self.dismiss(animated: true, completion: nil)
        }
        camera.didFinishCapturingImage = {(image: UIImage) in
            print("didFinishCapturingImage")
            
            self.dismiss(animated: true, completion: nil)
            
            self.imageView?.image = image
        }
        self.present(camera, animated: true, completion: nil)
    }
	
}

