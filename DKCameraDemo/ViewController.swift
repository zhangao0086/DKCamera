//
//  ViewController.swift
//  DKCameraDemo
//
//  Created by ZhangAo on 15/8/30.
//  Copyright (c) 2015年 ZhangAo. All rights reserved.
//

import UIKit

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
        camera.didCancelled = { () in
            println("didCancelled")
            
            self.dismissViewControllerAnimated(true, completion: nil)
        }

        camera.didFinishCapturingImage = {(image: UIImage) in
            println("didFinishCapturingImage")
            
            self.dismissViewControllerAnimated(true, completion: nil)
            
            self.imageView?.image = image
        }
        self.presentViewController(camera, animated: true, completion: nil)
        
    }
    
}

