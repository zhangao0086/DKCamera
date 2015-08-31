DKCamera
=======================

 [![Build Status](https://secure.travis-ci.org/zhangao0086/DKCamera.svg)](http://travis-ci.org/zhangao0086/DKCamera) [![Version Status](http://img.shields.io/cocoapods/v/DKCamera.png)][docsLink] [![license MIT](http://img.shields.io/badge/license-MIT-orange.png)][mitLink]
<img width="50%" height="50%" src="https://raw.githubusercontent.com/zhangao0086/DKImagePickerController/develop/Screenshot1.png" />
---


Update for Xcode 6.4 with Swift 1.2
---
## Description
New version! It's A Facebook style Image Picker Controller by Swift.  

## Requirements
* iOS 7.1+
* ARC

## Installation
#### iOS 8 and newer
DKImagePickerController is available on Cocoapods. Simply add the following line to your podfile:

```ruby
# For latest release in cocoapods
pod 'DKCamera'
```

#### iOS 7.x
To use Swift libraries on apps that support iOS 7, you must manually copy the files into your application project.
[iOS 7.x](https://github.com/CocoaPods/blog.cocoapods.org/commit/6933ae5ccfc1e0b39dd23f4ec67d7a083975836d)

## Easy to use

```swift

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

````

[docsLink]:http://cocoadocs.org/docsets/DKCamera
[mitLink]:http://opensource.org/licenses/MIT
