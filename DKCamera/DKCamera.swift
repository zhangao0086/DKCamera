//
//  DKCamera.swift
//  DKCameraDemo
//
//  Created by ZhangAo on 15/8/30.
//  Copyright (c) 2015年 ZhangAo. All rights reserved.
//

import UIKit
import AVFoundation
import CoreMotion
import ImageIO

extension AVMetadataFaceObject {

    open func realBounds(inCamera camera: DKCamera) -> CGRect {
        var bounds = CGRect()
        let previewSize = camera.previewView.bounds.size
        let isFront = camera.currentDevice == camera.captureDeviceFront
        
        if isFront {
            bounds.origin = CGPoint(x: previewSize.width - previewSize.width * (1 - self.bounds.origin.y - self.bounds.size.height / 2),
                                    y: previewSize.height * (self.bounds.origin.x + self.bounds.size.width / 2))
        } else {
            bounds.origin = CGPoint(x: previewSize.width * (1 - self.bounds.origin.y - self.bounds.size.height / 2),
                                    y: previewSize.height * (self.bounds.origin.x + self.bounds.size.width / 2))
        }
        bounds.size = CGSize(width: self.bounds.width * previewSize.height,
                             height: self.bounds.height * previewSize.width)
        return bounds
    }
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

@available(iOS, introduced: 10.0)
class DKCameraPhotoCapturer: NSObject, AVCapturePhotoCaptureDelegate {
    
    @available(iOS 12.0, *)
    class DKFileDataRepresentationCustomizer: NSObject, AVCapturePhotoFileDataRepresentationCustomizer {
    
        let metadata: [String: Any]
        
        init(metadata: [String: Any]) {
            self.metadata = metadata
            
            super.init()
        }
        
        public func replacementMetadata(for photo: AVCapturePhoto) -> [String : Any]? {
            return metadata
        }
    }
    
    var didCaptureWithImageData: ((_ imageData: Data) -> Void)?
    
    var gpsMetadata: [String: Any]?
    
    private var imageData: Data?
    
    #if swift(>=4.0)
    @available(iOS, deprecated: 11.0)
    func photoOutput(_ output: AVCapturePhotoOutput,
                     didFinishProcessingPhoto photoSampleBuffer: CMSampleBuffer?,
                     previewPhoto previewPhotoSampleBuffer: CMSampleBuffer?,
                     resolvedSettings: AVCaptureResolvedPhotoSettings,
                     bracketSettings: AVCaptureBracketedStillImageSettings?,
                     error: Error?) {
        guard let photoSampleBuffer = photoSampleBuffer else {
            print("DKCameraError: \(error!)")
            return
        }
        
        self.imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
    }
    
    @available(iOS, introduced: 11.0)
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        var metadata = photo.metadata
        
        if let gpsMetadata = self.gpsMetadata {
            metadata[kCGImagePropertyGPSDictionary as String] = gpsMetadata
            
            if #available(iOS 12.0, *) {
                self.imageData = photo.fileDataRepresentation(with: DKFileDataRepresentationCustomizer(metadata: metadata))
            } else {
                self.imageData = photo.fileDataRepresentation(withReplacementMetadata: metadata,
                                                              replacementEmbeddedThumbnailPhotoFormat: photo.embeddedThumbnailPhotoFormat,
                                                              replacementEmbeddedThumbnailPixelBuffer: nil,
                                                              replacementDepthData: photo.depthData)
            }
        } else {
            self.imageData = photo.fileDataRepresentation()
        }
    }
    
    func photoOutput(_ output: AVCapturePhotoOutput, didFinishCaptureFor resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("DKCameraError: \(error)")
        } else if let didCaptureWithImageData = self.didCaptureWithImageData {
            didCaptureWithImageData(self.imageData!)
        }
    }
    #else
    func capture(_ output: AVCapturePhotoOutput,
                 didFinishProcessingPhotoSampleBuffer photoSampleBuffer: CMSampleBuffer?,
                 previewPhotoSampleBuffer: CMSampleBuffer?,
                 resolvedSettings: AVCaptureResolvedPhotoSettings,
                 bracketSettings: AVCaptureBracketedStillImageSettings?,
                 error: Error?) {
        guard let photoSampleBuffer = photoSampleBuffer else {
            print("DKCameraError: \(error!)")
            return
        }
        
        self.imageData = AVCapturePhotoOutput.jpegPhotoDataRepresentation(forJPEGSampleBuffer: photoSampleBuffer, previewPhotoSampleBuffer: previewPhotoSampleBuffer)
    }
    
    func capture(_ output: AVCapturePhotoOutput, didFinishCaptureForResolvedSettings resolvedSettings: AVCaptureResolvedPhotoSettings, error: Error?) {
        if let error = error {
            print("DKCameraError: \(error)")
        } else if let didCaptureWithImageData = self.didCaptureWithImageData {
            didCaptureWithImageData(self.imageData!)
        }
    }

    #endif
    
}

//////////////////////////////////////////////////////////////////////////////////////////////////////

@objc
public enum DKCameraDeviceSourceType : Int {
    case front, rear
}

open class DKCamera: UIViewController, AVCaptureMetadataOutputObjectsDelegate {
    
    open class DKCameraPreviewView: UIView {
        
        var videoPreviewLayer: AVCaptureVideoPreviewLayer {
            guard let layer = layer as? AVCaptureVideoPreviewLayer else {
                fatalError("Expected `AVCaptureVideoPreviewLayer` type for layer. Check DKCameraPreviewView.layerClass implementation.")
            }
            return layer
        }
        
        var session: AVCaptureSession? {
            get { return videoPreviewLayer.session }
            set { videoPreviewLayer.session = newValue }
        }
        
        open override class var layerClass: AnyClass {
            return AVCaptureVideoPreviewLayer.self
        }
        
    }
    
    open class func checkCameraPermission(_ handler: @escaping (_ granted: Bool) -> Void) {
        func hasCameraPermission() -> Bool {
            #if swift(>=4.0)
            return AVCaptureDevice.authorizationStatus(for: .video) == .authorized
            #else
            return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) == .authorized
            #endif
        }
        
        func needsToRequestCameraPermission() -> Bool {
            #if swift(>=4.0)
            return AVCaptureDevice.authorizationStatus(for: .video) == .notDetermined
            #else
            return AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo) == .notDetermined
            #endif
        }
        
        #if swift(>=4.0)
        hasCameraPermission() ? handler(true) : (needsToRequestCameraPermission() ?
            AVCaptureDevice.requestAccess(for: .video, completionHandler: { granted in
                DispatchQueue.main.async(execute: { () -> Void in
                    hasCameraPermission() ? handler(true) : handler(false)
                })
            }) : handler(false))
        #else
        hasCameraPermission() ? handler(true) : (needsToRequestCameraPermission() ?
            AVCaptureDevice.requestAccess(forMediaType: AVMediaTypeVideo, completionHandler: { granted in
                DispatchQueue.main.async(execute: { () -> Void in
                    hasCameraPermission() ? handler(true) : handler(false)
                })
            }) : handler(false))
        #endif
    }
    
    open var didCancel: (() -> Void)?
    open var didFinishCapturingImage: ((_ image: UIImage, _ metadata: [AnyHashable : Any]?) -> Void)?
    
    /// Photos will be tagged with the location where they are taken.
    /// Must add the "Privacy - Location XXX" tag to your Info.plist.
    open var containsGPSInMetadata = false
    
    /// Notify the listener of the detected faces in the preview frame.
    open var onFaceDetection: ((_ faces: [AVMetadataFaceObject]) -> Void)?
    
    /// Be careful this may cause the view to load prematurely.
    open var cameraOverlayView: UIView? {
        didSet {
            if let cameraOverlayView = cameraOverlayView {
                self.view.addSubview(cameraOverlayView)
            }
        }
    }
    
    /// The flashModel will to be remembered to next use.
    open var flashMode: AVCaptureDevice.FlashMode! {
        didSet {
            self.updateFlashButton()
            self.updateFlashMode()
            self.updateFlashModeToUserDefautls(self.flashMode)
        }
    }
    
    open class func isAvailable() -> Bool {
        return UIImagePickerController.isSourceTypeAvailable(.camera)
    }
    
    /// Determines whether or not the rotation is enabled.
    
    open var allowsRotate = false
    
    /// set to NO to hide all standard camera UI. default is YES.
    open var showsCameraControls = true {
        didSet {
            self.contentView.isHidden = !self.showsCameraControls
        }
    }
    
    public let captureSession = AVCaptureSession()
    open var previewView = DKCameraPreviewView()
    fileprivate let sessionQueue = DispatchQueue(label: "DKCamera_CaptureSession_Queue")
    fileprivate var beginZoomScale: CGFloat = 1.0
    fileprivate var zoomScale: CGFloat = 1.0
    
    open var defaultCaptureDevice = DKCameraDeviceSourceType.rear
    open var currentDevice: AVCaptureDevice?
    open var captureDeviceFront: AVCaptureDevice?
    open var captureDeviceRear: AVCaptureDevice?
    
    open var locationManager: DKCameraLocationManager?
    
    fileprivate weak var captureOutput: AVCaptureOutput?
    
    fileprivate var __defaultPhotoSettings: Any?
    @available(iOS 10.0, *)
    fileprivate var defaultPhotoSettings: AVCapturePhotoSettings {
        get {
            if __defaultPhotoSettings == nil {
                let photoSettings = AVCapturePhotoSettings()
                photoSettings.isHighResolutionPhotoEnabled = true
                
                __defaultPhotoSettings = photoSettings
            }
            
            return __defaultPhotoSettings as! AVCapturePhotoSettings
        }
    }
    
    open var previewLayer: AVCaptureVideoPreviewLayer {
        return self.previewView.videoPreviewLayer
    }
    
    open var contentView = UIView()
    
    open var originalOrientation: UIDeviceOrientation!
    open var currentOrientation: UIDeviceOrientation!
    public let motionManager = CMMotionManager()
    
    open lazy var flashButton: UIButton = {
        let flashButton = UIButton()
        flashButton.addTarget(self, action: #selector(DKCamera.switchFlashMode), for: .touchUpInside)
        
        return flashButton
    }()
    open var cameraSwitchButton: UIButton!
    open var captureButton: UIButton!
    
    let cameraResource: DKCameraResource
    
    public init() {
        self.cameraResource = DKDefaultCameraResource()
        
        super.init(nibName: nil, bundle: nil)
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.modalPresentationStyle = .fullScreen
        }
    }
    
    public init(cameraResource: DKCameraResource) {
        self.cameraResource = cameraResource

        super.init(nibName: nil, bundle: nil)
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.modalPresentationStyle = .fullScreen
        }
    }
    
    required public init?(coder aDecoder: NSCoder) {
        self.cameraResource = DKDefaultCameraResource()
        
        super.init(coder: aDecoder)
        
        if UIDevice.current.userInterfaceIdiom == .phone {
            self.modalPresentationStyle = .fullScreen
        }
    }
    
    override open func viewDidLoad() {
        super.viewDidLoad()
        
        self.view.backgroundColor = UIColor.black
        
        self.setupDevices()
        self.setupUI()
        self.setupSession()
        
        self.setupMotionManager()
        
        if self.containsGPSInMetadata {
            self.locationManager = DKCameraLocationManager()
        }
    }
    
    open override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        if !self.captureSession.isRunning {
            self.captureSession.startRunning()
        }
        
        func initialOriginalOrientationForOrientationIfNeeded() {
            if self.originalOrientation == nil {
                self.initialOriginalOrientationForOrientation()
                self.currentOrientation = self.originalOrientation
            }
        }
        
        if !self.motionManager.isAccelerometerActive {
            if UIDevice.current.userInterfaceIdiom == .pad {
                let requiresFullScreen = Bundle.main.infoDictionary?["UIRequiresFullScreen"]
                if requiresFullScreen == nil || !(requiresFullScreen as! Bool) {
                    initialOriginalOrientationForOrientationIfNeeded()
                    return
                }                
            }
            self.motionManager.startAccelerometerUpdates(to: OperationQueue.current!, withHandler: { accelerometerData, error in
                if error == nil {
                    let currentOrientation = accelerometerData!.acceleration.toDeviceOrientation() ?? self.currentOrientation
                    initialOriginalOrientationForOrientationIfNeeded()
                    if let currentOrientation = currentOrientation, self.currentOrientation != currentOrientation {
                        self.currentOrientation = currentOrientation
                        self.updateContentLayoutForCurrentOrientation()
                    }
                } else {
                    print("error while update accelerometer: \(error!.localizedDescription)", terminator: "")
                }
            })
        }
        
        self.updateSession(isEnable: true)
    }
        
    open override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        self.locationManager?.startUpdatingLocation()
    }
    
    open override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        
        self.updateSession(isEnable: false)
        self.motionManager.stopAccelerometerUpdates()
        self.locationManager?.stopUpdatingLocation()
    }
    
    /*
         If setupUI() is called before the view has loaded,
         it doesn't have safe area insets yet, so we need to
         implement this function to do re-sizing if the safe area
         insets change
     */
    @available(iOS 11.0, *)
    open override func viewSafeAreaInsetsDidChange() {
        super.viewSafeAreaInsetsDidChange()
        
        // Handle iPhone X notch - resize bottom view to respect safe area
        let safeAreaBottomInset = view.safeAreaInsets.bottom
        let bottomViewContainerHeight = bottomView.frame.size.height + safeAreaBottomInset
        bottomViewContainer.frame = CGRect(x: 0,
                                           y: contentView.bounds.height - bottomViewContainerHeight,
                                           width:contentView.bounds.width,
                                           height:bottomViewContainerHeight)
    }
    
    override open func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
    open override var prefersStatusBarHidden : Bool {
        return true
    }
    
    // MARK: - Setup
    
    let bottomViewContainer = UIView()
    let bottomView = UIView()
    open func setupUI() {
        self.view.addSubview(self.contentView)
        self.contentView.backgroundColor = UIColor.clear
        self.contentView.translatesAutoresizingMaskIntoConstraints = false
        
        if #available(iOS 9.0, *) {
            var constraints = [
                self.contentView.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
                self.contentView.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
                self.contentView.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
            ]
            
            if #available(iOS 11.0, *) {
                constraints.append(self.contentView.topAnchor.constraint(equalTo: self.view.safeAreaLayoutGuide.topAnchor))
            } else {
                constraints.append(self.contentView.topAnchor.constraint(equalTo: self.view.topAnchor))
            }
            
            NSLayoutConstraint.activate(constraints)
        } else {
            let viewsDict = ["contentView" : self.contentView]
            
            self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "H:|-0-[contentView]-0-|", options: [], metrics: nil, views: viewsDict))
            self.view.addConstraints(NSLayoutConstraint.constraints(withVisualFormat: "V:|-0-[contentView]-0-|", options: [], metrics: nil, views: viewsDict))
        }
        
        let bottomViewHeight: CGFloat = 70
        
        bottomView.frame = CGRect(x: 0, y: 0, width: contentView.bounds.width, height: bottomViewHeight)
        bottomView.autoresizingMask = [.flexibleWidth]
        bottomViewContainer.addSubview(bottomView)
        
        bottomViewContainer.backgroundColor = UIColor(white: 0, alpha: 0.4)
        bottomViewContainer.addSubview(bottomView)
        
        var bottomViewContainerHeight = bottomView.bounds.height
        if #available(iOS 11, *) {
            // Handle iPhone X notch - respect safe area
            let safeAreaBottomInset = view.safeAreaInsets.bottom
            bottomViewContainerHeight = bottomViewContainerHeight + safeAreaBottomInset
        }
        
        bottomViewContainer.frame = CGRect(x: 0, y: contentView.bounds.height - bottomViewContainerHeight, width: contentView.bounds.width, height: bottomViewContainerHeight)
        bottomViewContainer.autoresizingMask = [.flexibleWidth, .flexibleTopMargin]
        contentView.addSubview(bottomViewContainer)
        
        // switch button
        let cameraSwitchButton: UIButton = {
            let cameraSwitchButton = UIButton()
            cameraSwitchButton.addTarget(self, action: #selector(DKCamera.switchCamera), for: .touchUpInside)
            cameraSwitchButton.setImage(cameraResource.cameraSwitchImage(), for: .normal)
            cameraSwitchButton.sizeToFit()
            
            return cameraSwitchButton
        }()
        
        cameraSwitchButton.frame.origin = CGPoint(x: bottomView.bounds.width - cameraSwitchButton.bounds.width - 15,
                                                  y: (bottomView.bounds.height - cameraSwitchButton.bounds.height) / 2)
        cameraSwitchButton.autoresizingMask = [.flexibleLeftMargin, .flexibleTopMargin, .flexibleBottomMargin]
        bottomView.addSubview(cameraSwitchButton)
        self.cameraSwitchButton = cameraSwitchButton
        
        // capture button
        let captureButton: UIButton = {
            
            class DKCaptureButton: UIButton {
                fileprivate override func beginTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
                    self.backgroundColor = UIColor.white
                    return true
                }
                
                fileprivate override func continueTracking(_ touch: UITouch, with event: UIEvent?) -> Bool {
                    self.backgroundColor = UIColor.white
                    return true
                }
                
                fileprivate override func endTracking(_ touch: UITouch?, with event: UIEvent?) {
                    self.backgroundColor = nil
                }
                
                fileprivate override func cancelTracking(with event: UIEvent?) {
                    self.backgroundColor = nil
                }
            }
            
            let captureButton = DKCaptureButton()
            captureButton.addTarget(self, action: #selector(DKCamera.takePicture), for: .touchUpInside)
            captureButton.bounds.size = CGSize(width: bottomViewHeight,
                                               height: bottomViewHeight).applying(CGAffineTransform(scaleX: 0.9, y: 0.9))
            captureButton.layer.cornerRadius = captureButton.bounds.height / 2
            captureButton.layer.borderColor = UIColor.white.cgColor
            captureButton.layer.borderWidth = 2
            captureButton.layer.masksToBounds = true
            
            return captureButton
        }()
        
        captureButton.center = CGPoint(x: bottomView.bounds.width / 2, y: bottomView.bounds.height / 2)
        captureButton.autoresizingMask = [.flexibleLeftMargin, .flexibleRightMargin]
        bottomView.addSubview(captureButton)
        self.captureButton = captureButton
        
        // cancel button
        let cancelButton: UIButton = {
            let cancelButton = UIButton()
            cancelButton.addTarget(self, action: #selector(DKCamera.dismissCamera), for: .touchUpInside)
            cancelButton.setImage(cameraResource.cameraCancelImage(), for: .normal)
            cancelButton.sizeToFit()
            
            return cancelButton
        }()
        
        cancelButton.frame.origin = CGPoint(x: contentView.bounds.width - cancelButton.bounds.width - 15, y: 25)
        cancelButton.autoresizingMask = [.flexibleBottomMargin, .flexibleLeftMargin]
        contentView.addSubview(cancelButton)
        
        self.flashButton.frame.origin = CGPoint(x: 5, y: 15)
        contentView.addSubview(self.flashButton)
        
        contentView.addGestureRecognizer(UIPinchGestureRecognizer(target: self, action: #selector(DKCamera.handleZoom(_:))))
        contentView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(DKCamera.handleFocus(_:))))
    }
    
    open func setupSession() {
        #if swift(>=4.0)
        self.captureSession.sessionPreset = .photo
        #else
        self.captureSession.sessionPreset = AVCaptureSessionPresetPhoto
        #endif
        
        self.setupCurrentDevice()
        
        var captureOutput: AVCaptureOutput!
        if #available(iOS 10.0, *) {
            let photoOutput = AVCapturePhotoOutput()
            photoOutput.isHighResolutionCaptureEnabled = true
            captureOutput = photoOutput
        } else {
            captureOutput = AVCaptureStillImageOutput()
        }
        
        if self.captureSession.canAddOutput(captureOutput) {
            self.captureSession.addOutput(captureOutput)
            self.captureOutput = captureOutput
        }

        if self.onFaceDetection != nil {
            let metadataOutput = AVCaptureMetadataOutput()
            metadataOutput.setMetadataObjectsDelegate(self, queue: DispatchQueue(label: "DKCamera_MetadataOutputQueue"))
            
            if self.captureSession.canAddOutput(metadataOutput) {
                self.captureSession.addOutput(metadataOutput)
                #if swift(>=4.0)
                metadataOutput.metadataObjectTypes = [.face]
                #else
                metadataOutput.metadataObjectTypes = [AVMetadataObjectTypeFace]
                #endif
            }
        }
        
        self.previewView.session = self.captureSession
        
        #if swift(>=4.0)
        self.previewLayer.videoGravity = .resizeAspectFill
        #else
        self.previewLayer.videoGravity = AVLayerVideoGravityResizeAspectFill
        #endif
        
        self.view.insertSubview(self.previewView, at: 0)
        self.previewView.frame = self.view.bounds
        self.previewView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    }
    
    open func setupCurrentDevice() {
        if let currentDevice = self.currentDevice {
            
            if currentDevice.isFlashAvailable {
                self.flashButton.isHidden = false
                self.flashMode = self.flashModeFromUserDefaults()
            } else {
                self.flashButton.isHidden = true
            }
            
            #if swift(>=4.0)
            for oldInput in self.captureSession.inputs {
                self.captureSession.removeInput(oldInput)
            }
            #else
            for oldInput in self.captureSession.inputs as! [AVCaptureInput] {
                self.captureSession.removeInput(oldInput)
            }
            #endif
            
            if let frontInput = try? AVCaptureDeviceInput(device: currentDevice) {
                if self.captureSession.canAddInput(frontInput) {
                    self.captureSession.addInput(frontInput)
                }
            }
            
            try! currentDevice.lockForConfiguration()
            if currentDevice.isFocusModeSupported(.continuousAutoFocus) {
                currentDevice.focusMode = .continuousAutoFocus
            }
            
            if currentDevice.isExposureModeSupported(.continuousAutoExposure) {
                currentDevice.exposureMode = .continuousAutoExposure
            }
            
            currentDevice.unlockForConfiguration()
        }
    }
    
    open func setupDevices() {
        if #available(iOS 10.0, *) {
            #if swift(>=4.0)
            self.captureDeviceFront = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .front)
            self.captureDeviceRear = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back)
            #else
            self.captureDeviceFront = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .front)
            self.captureDeviceRear = AVCaptureDevice.defaultDevice(withDeviceType: .builtInWideAngleCamera, mediaType: AVMediaTypeVideo, position: .back)
            #endif
        } else {
            #if swift(>=4.0)
            let devices = AVCaptureDevice.devices(for: .video)
            #else
            let devices = AVCaptureDevice.devices(withMediaType: AVMediaTypeVideo) as! [AVCaptureDevice]
            #endif
            
            for device in devices {
                if device.position == .back {
                    self.captureDeviceRear = device
                }
                
                if device.position == .front {
                    self.captureDeviceFront = device
                }
            }
        }

        switch self.defaultCaptureDevice {
        case .front:
            self.currentDevice = self.captureDeviceFront ?? self.captureDeviceRear
        case .rear:
            self.currentDevice = self.captureDeviceRear ?? self.captureDeviceFront
        }
    }
    
    @objc internal func dismissCamera() {
        self.didCancel?()
    }
    
    // MARK: - Session
    
    fileprivate var isStopped = false
    
    open func startSession() {
        self.isStopped = false
        
        if !self.captureSession.isRunning {
            self.captureSession.startRunning()
        }
    }
    
    open func stopSession() {
        self.pauseSession()
        
        self.captureSession.stopRunning()
    }
    
    open func pauseSession() {
        self.isStopped = true
        
        self.updateSession(isEnable: false)
    }
    
    open func updateSession(isEnable: Bool) {
        if ((!self.isStopped) || (self.isStopped && !isEnable)),
            let connection = self.previewLayer.connection {
            connection.isEnabled = isEnable
        }
    }
    
    // MARK: - Capture Image
    
    @objc open func takePicture() {
        #if swift(>=4.0)
        let authStatus = AVCaptureDevice.authorizationStatus(for: .video)
        #else
        let authStatus = AVCaptureDevice.authorizationStatus(forMediaType: AVMediaTypeVideo)
        #endif
        
        if authStatus == .denied {
            return
        }
        
        guard let didFinishCapturingImage = self.didFinishCapturingImage else { return }
        
        guard self.readyToCaptureImage() else { return }
        
        self.captureButton.isEnabled = false
        
        self.sessionQueue.async {
            self.captureImage { (cropTakenImage, metadata, error) in
                if let error = error {
                    print("DKCamera encountered error while capturing still image: \(error.localizedDescription)")
                } else {
                    didFinishCapturingImage(cropTakenImage!, metadata)
                }
                
                self.captureButton.isEnabled = true
            }
        }
    }
    
    private func readyToCaptureImage() -> Bool {
        if #available(iOS 10.0, *) {
            if let _ = self.captureOutput as? AVCapturePhotoOutput, self.currentCapturer == nil {
                return true
            } else {
                return false
            }
        } else {
            if let stillImageOutput = self.captureOutput as? AVCaptureStillImageOutput, !stillImageOutput.isCapturingStillImage {
                return true
            } else {
                return false
            }
        }
    }
    
    fileprivate var currentCapturer: Any? // DKCameraPhotoCapturer
    private func captureImage(_ completeBlock: @escaping (_ image: UIImage?, _ metadata: [AnyHashable : Any]?, _ error: Error?) -> Void) {
        
        func process(_ imageData: Data) {
            let takenImage = UIImage(data: imageData)!
            let cropTakenImage = self.cropImage(with: takenImage)
            let metadata = self.extractMetadata(from: imageData)
            
            completeBlock(cropTakenImage, metadata, nil)
        }
        
        if #available(iOS 10.0, *) {
            if let photoCapture = self.captureOutput as? AVCapturePhotoOutput {
                #if swift(>=4.0)
                guard let connection = photoCapture.connection(with: .video) else { return }
                #else
                guard let connection = photoCapture.connection(withMediaType: AVMediaTypeVideo) else { return }
                #endif
                
                connection.videoOrientation = self.currentOrientation.toAVCaptureVideoOrientation()
                connection.videoScaleAndCropFactor = self.zoomScale
                
                let settings = AVCapturePhotoSettings(from: self.defaultPhotoSettings)
                
                let capturer = DKCameraPhotoCapturer()
                
                if let gpsMetadata = self.locationManager?.gpsMetadataForLatestLocation() {
                    capturer.gpsMetadata = gpsMetadata
                }
                
                capturer.didCaptureWithImageData = { imageData in
                    process(imageData)
                    self.currentCapturer = nil
                }
                
                photoCapture.capturePhoto(with: settings, delegate: capturer)
                
                self.currentCapturer = capturer
            }
        } else {
            if let stillImageOutput = self.captureOutput as? AVCaptureStillImageOutput {
                #if swift(>=4.0)
                guard let connection = stillImageOutput.connection(with: .video) else { return }
                #else
                guard let connection = stillImageOutput.connection(withMediaType: AVMediaTypeVideo) else { return }
                #endif
                
                connection.videoOrientation = self.currentOrientation.toAVCaptureVideoOrientation()
                connection.videoScaleAndCropFactor = self.zoomScale
                
                stillImageOutput.captureStillImageAsynchronously(from: connection, completionHandler: { (imageDataSampleBuffer, error) in
                    if error == nil {
                        let imageData = AVCaptureStillImageOutput.jpegStillImageNSDataRepresentation(imageDataSampleBuffer!)
                        
                        if let imageData = imageData {
                            process(imageData)
                        } else {
                            completeBlock(nil, nil, NSError(domain: "DKCamera", code: -1,
                                                            userInfo: 
                                [ NSLocalizedDescriptionKey : "DKCamera encountered an Unknown error" ]))
                        }
                    } else {
                        completeBlock(nil, nil, error)
                    }
                })
            }
        }
    }
    
    private func cropImage(with takenImage: UIImage) -> UIImage {
        #if swift(>=4.0)
        let outputRect = self.previewLayer.metadataOutputRectConverted(fromLayerRect: self.previewLayer.bounds)
        #else
        let outputRect = self.previewLayer.metadataOutputRectOfInterest(for: self.previewLayer.bounds)
        #endif
        let takenCGImage = takenImage.cgImage!
        let width = CGFloat(takenCGImage.width)
        let height = CGFloat(takenCGImage.height)
        let cropRect = CGRect(x: outputRect.origin.x * width, y: outputRect.origin.y * height, width: outputRect.size.width * width, height: outputRect.size.height * height)
        
        let cropCGImage = takenCGImage.cropping(to: cropRect)
        let cropTakenImage = UIImage(cgImage: cropCGImage!, scale: 1, orientation: takenImage.imageOrientation)

        return cropTakenImage
    }
    
    private func extractMetadata(from imageData: Data) -> [AnyHashable : Any]? {
        if let source = CGImageSourceCreateWithData(imageData as CFData, nil) {
            return CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [AnyHashable : Any]
        } else {
            return nil
        }
    }
    
    // MARK: - Handles Zoom
    
    @objc open func handleZoom(_ gesture: UIPinchGestureRecognizer) {
        if gesture.state == .began {
            self.beginZoomScale = self.zoomScale
        } else if gesture.state == .changed {
            self.zoomScale = min(4.0, max(1.0, self.beginZoomScale * gesture.scale))
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.025)
            self.previewLayer.setAffineTransform(CGAffineTransform(scaleX: self.zoomScale, y: self.zoomScale))
            CATransaction.commit()
        }
    }
    
    // MARK: - Handles Focus
    
    @objc open func handleFocus(_ gesture: UITapGestureRecognizer) {
        if let currentDevice = self.currentDevice , currentDevice.isFocusPointOfInterestSupported {
            let touchPoint = gesture.location(in: self.view)
            self.focusAtTouchPoint(touchPoint)
        }
    }
    
    open func focusAtTouchPoint(_ touchPoint: CGPoint) {
        
        func showFocusViewAtPoint(_ touchPoint: CGPoint) {
            
            struct FocusView {
                static let focusView: UIView = {
                    let focusView = UIView()
                    let diameter: CGFloat = 100
                    focusView.bounds.size = CGSize(width: diameter, height: diameter)
                    focusView.layer.borderWidth = 2
                    focusView.layer.cornerRadius = diameter / 2
                    focusView.layer.borderColor = UIColor.white.cgColor
                    
                    return focusView
                }()
            }
            FocusView.focusView.transform = CGAffineTransform.identity
            FocusView.focusView.center = touchPoint
            self.view.addSubview(FocusView.focusView)
            
            UIView.animate(withDuration: 0.7, delay: 0, usingSpringWithDamping: 0.5, initialSpringVelocity: 1.1,
                           options: [], animations: { () -> Void in
                            FocusView.focusView.transform = CGAffineTransform.identity.scaledBy(x: 0.6, y: 0.6)
            }) { (Bool) -> Void in
                FocusView.focusView.removeFromSuperview()
            }
        }
        
        if self.currentDevice == nil || self.currentDevice?.isFocusPointOfInterestSupported == false {
            return
        }
        
        #if swift(>=4.0)
        let focusPoint = self.previewLayer.captureDevicePointConverted(fromLayerPoint: touchPoint)
        #else
        let focusPoint = self.previewLayer.captureDevicePointOfInterest(for: touchPoint)
        #endif
        
        showFocusViewAtPoint(touchPoint)
        
        if let currentDevice = self.currentDevice {
            try! currentDevice.lockForConfiguration()
            currentDevice.focusPointOfInterest = focusPoint
            currentDevice.exposurePointOfInterest = focusPoint
            
            currentDevice.focusMode = .continuousAutoFocus
            
            if currentDevice.isExposureModeSupported(.continuousAutoExposure) {
                currentDevice.exposureMode = .continuousAutoExposure
            }
            
            currentDevice.unlockForConfiguration()
        }
        
    }
    
    // MARK: - Handles Switch Camera
    
    @objc internal func switchCamera() {
        self.currentDevice = self.currentDevice == self.captureDeviceRear ?
            self.captureDeviceFront : self.captureDeviceRear
        
        self.setupCurrentDevice()
    }
    
    // MARK: - Handles Flash
    
    @objc internal func switchFlashMode() {
        switch self.flashMode! {
        case .auto:
            self.flashMode = .off
        case .on:
            self.flashMode = .auto
        case .off:
            self.flashMode = .on
        @unknown default:
            self.flashMode = .auto
        }
    }
    
    open func flashModeFromUserDefaults() -> AVCaptureDevice.FlashMode {
        let rawValue = UserDefaults.standard.integer(forKey: "DKCamera.flashMode")
        return AVCaptureDevice.FlashMode(rawValue: rawValue)!
    }
    
    open func updateFlashModeToUserDefautls(_ flashMode: AVCaptureDevice.FlashMode) {
        UserDefaults.standard.set(flashMode.rawValue, forKey: "DKCamera.flashMode")
    }
    
    open func updateFlashButton() {
        struct FlashImage {
            let images: [AVCaptureDevice.FlashMode: UIImage]
            
            init(cameraResource: DKCameraResource) {
                self.images = [
                    AVCaptureDevice.FlashMode.auto : cameraResource.cameraFlashAutoImage(),
                    AVCaptureDevice.FlashMode.on : cameraResource.cameraFlashOnImage(),
                    AVCaptureDevice.FlashMode.off : cameraResource.cameraFlashOffImage()
                ]
            }

            
        }
        let flashImage: UIImage = FlashImage(cameraResource:cameraResource).images[self.flashMode]!
        
        self.flashButton.setImage(flashImage, for: .normal)
        self.flashButton.sizeToFit()
    }
    
    open func updateFlashMode() {
        if let currentDevice = self.currentDevice, let captureOutput = self.captureOutput, currentDevice.isFlashAvailable  {
            if #available(iOS 10.0, *) {
                let isFlashModeSupported = (captureOutput as! AVCapturePhotoOutput).__supportedFlashModes.contains(NSNumber(value: self.flashMode.rawValue))
                if isFlashModeSupported {
                    self.defaultPhotoSettings.flashMode = self.flashMode
                }
            } else {
                if currentDevice.isFlashModeSupported(self.flashMode) {
                    try! currentDevice.lockForConfiguration()
                    currentDevice.flashMode = self.flashMode
                    currentDevice.unlockForConfiguration()
                }
            }
        }
    }
    
    // MARK: - AVCaptureMetadataOutputObjectsDelegate
    
    public func metadataOutput(_ captureOutput: AVCaptureMetadataOutput, didOutput metadataObjects: [AVMetadataObject], from connection: AVCaptureConnection) {
        self.onFaceDetection?(metadataObjects as! [AVMetadataFaceObject])
    }
    
    // MARK: - Handles Orientation
    
    open override var shouldAutorotate : Bool {
        return false
    }
    
    open override func viewWillTransition(to size: CGSize, with coordinator: UIViewControllerTransitionCoordinator) {
        super.viewWillTransition(to: size, with: coordinator)
        
        if UIApplication.shared.applicationState == .background { return }
        
        coordinator.animate(alongsideTransition: { context in
            let deviceOrientation = UIDevice.current.orientation
            if !(deviceOrientation.isPortrait || deviceOrientation.isLandscape) {
                    return
            }

            self.initialOriginalOrientationForOrientation()
            self.currentOrientation = self.originalOrientation
        })
    }
    
    open func setupMotionManager() {
        self.motionManager.accelerometerUpdateInterval = 0.5
        self.motionManager.gyroUpdateInterval = 0.5
    }
    
    open func initialOriginalOrientationForOrientation() {
        self.originalOrientation = UIApplication.shared.statusBarOrientation.toDeviceOrientation()
        if let connection = self.previewLayer.connection {
            connection.videoOrientation = self.originalOrientation.toAVCaptureVideoOrientation()
        }
    }
    
    open func updateContentLayoutForCurrentOrientation() {
        let newAngle = self.currentOrientation.toAngleRelativeToPortrait() - self.originalOrientation.toAngleRelativeToPortrait()
        
        if self.allowsRotate {
            var contentViewNewSize: CGSize!
            let width = self.view.bounds.width
            let height = self.view.bounds.height
            if self.currentOrientation.isLandscape {
                contentViewNewSize = CGSize(width: max(width, height), height: min(width, height))
            } else {
                contentViewNewSize = CGSize(width: min(width, height), height: max(width, height))
            }
            
            UIView.animate(withDuration: 0.2, animations: {
                self.contentView.bounds.size = contentViewNewSize
                self.contentView.transform = CGAffineTransform(rotationAngle: newAngle)
            })
        } else {
            let rotateAffineTransform = CGAffineTransform.identity.rotated(by: newAngle)
            
            UIView.animate(withDuration: 0.2, animations: {
                self.flashButton.transform = rotateAffineTransform
                self.cameraSwitchButton.transform = rotateAffineTransform
            })
        }
    }
    
}

// MARK: - Utilities

public extension UIInterfaceOrientation {
    
    func toDeviceOrientation() -> UIDeviceOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeRight:
            return .landscapeLeft
        case .landscapeLeft:
            return .landscapeRight
        default:
            return .portrait
        }
    }
}

public extension UIDeviceOrientation {
    
    func toAVCaptureVideoOrientation() -> AVCaptureVideoOrientation {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeRight:
            return .landscapeLeft
        case .landscapeLeft:
            return .landscapeRight
        default:
            return .portrait
        }
    }
    
    func toInterfaceOrientationMask() -> UIInterfaceOrientationMask {
        switch self {
        case .portrait:
            return .portrait
        case .portraitUpsideDown:
            return .portraitUpsideDown
        case .landscapeRight:
            return .landscapeLeft
        case .landscapeLeft:
            return .landscapeRight
        default:
            return .portrait
        }
    }
    
    func toAngleRelativeToPortrait() -> CGFloat {
        switch self {
        case .portrait:
            return 0
        case .portraitUpsideDown:
            return CGFloat.pi
        case .landscapeRight:
            return -CGFloat.pi / 2.0
        case .landscapeLeft:
            return CGFloat.pi / 2.0
        default:
            return 0.0
        }
    }
    
}

public extension CMAcceleration {
    func toDeviceOrientation() -> UIDeviceOrientation? {
        if self.x >= 0.75 {
            return .landscapeRight
        } else if self.x <= -0.75 {
            return .landscapeLeft
        } else if self.y <= -0.75 {
            return .portrait
        } else if self.y >= 0.75 {
            return .portraitUpsideDown
        } else {
            return nil
        }
    }
}

// MARK: - Rersources

public extension Bundle {
    
    class func cameraBundle() -> Bundle {
        let assetPath = Bundle(for: DKDefaultCameraResource.self).resourcePath!
        return Bundle(path: (assetPath as NSString).appendingPathComponent("DKCameraResource.bundle"))!
    }
    
}

open class DKDefaultCameraResource: DKCameraResource {
    
    open func imageForResource(_ name: String) -> UIImage {
        let bundle = Bundle.cameraBundle()
        let imagePath = bundle.path(forResource: name, ofType: "png", inDirectory: "Images")
        let image = UIImage(contentsOfFile: imagePath!)
        return image!
    }
    
     public func cameraCancelImage() -> UIImage {
        return imageForResource("camera_cancel")
    }
    
     public func cameraFlashOnImage() -> UIImage {
        return imageForResource("camera_flash_on")
    }
    
     public func cameraFlashAutoImage() -> UIImage {
        return imageForResource("camera_flash_auto")
    }
    
     public func cameraFlashOffImage() -> UIImage {
        return imageForResource("camera_flash_off")
    }
    
     public func cameraSwitchImage() -> UIImage {
        return imageForResource("camera_switch")
    }
    
}

