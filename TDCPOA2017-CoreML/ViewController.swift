//
//  ViewController.swift
//  TDCPOA2017-CoreML
//
//  Created by Henrique Valcanaia on 29/10/17.
//  Copyright © 2017 Henrique Valcanaia. All rights reserved.
//

import AVFoundation
import CoreML
import UIKit
import Vision

class ViewController: UIViewController {
     
    private let model = food().model
    private var request: VNCoreMLRequest!
    
    @IBOutlet weak var foodLabel: UILabel!
    
    private lazy var captureSession: AVCaptureSession = {
        let session = AVCaptureSession()
        session.sessionPreset = .high
        
        guard let backCamera = AVCaptureDevice.default(for: .video), let input = try? AVCaptureDeviceInput(device: backCamera) else {
            print("Error getting back camera or creating input")
            return session
        }
        
        do {
            try backCamera.lockForConfiguration()
            backCamera.focusMode = .continuousAutoFocus
            backCamera.unlockForConfiguration()
            
            let videoOutput = AVCaptureVideoDataOutput()
            videoOutput.setSampleBufferDelegate(self, queue: DispatchQueue(label: "sample buffer delegate"))
            
            session.addInput(input)
            session.addOutput(videoOutput)
        } catch let error {
            print(error)
        }
        
        return session
    }()
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        do {
            let visionModel = try VNCoreMLModel(for: model)
            request = VNCoreMLRequest(model: visionModel, completionHandler: visionCallback(request:error:))
        } catch let error {
            print("Error trying to create Vision model. \n \(error)")
        }
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        configureViews()
        captureSession.startRunning()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        captureSession.stopRunning()
    }
    
    // MARK: Private helpers
    private func configureViews() {
        let previewLayer = AVCaptureVideoPreviewLayer(session: captureSession)
        view.layer.insertSublayer(previewLayer, at: 0)
        previewLayer.frame = view.layer.frame
    }
    
    private func visionCallback(request: VNRequest, error: Error?) {
        guard let results = request.results as? [VNClassificationObservation] else {
            fatalError("Unexpected runtime error")
        }
        
        var text = "Not accurate enough"
        if let maxConfidence = results.max(by: { $0.confidence < $1.confidence }) {
            let confidencePercentageText = String(format: "%.2f", maxConfidence.confidence*100)
            text = "\(maxConfidence.identifier) \(confidencePercentageText)%"
        }
        
        DispatchQueue.main.async { [weak self] in
            self?.foodLabel.text = text
        }
    }
    
}

// MARK: - AVCaptureVideoDataOutputSampleBufferDelegate
extension ViewController: AVCaptureVideoDataOutputSampleBufferDelegate {
    func captureOutput(_ output: AVCaptureOutput, didOutput sampleBuffer: CMSampleBuffer, from connection: AVCaptureConnection) {
        if let pixelBuffer = CMSampleBufferGetImageBuffer(sampleBuffer) {
            let handler = VNImageRequestHandler(cvPixelBuffer: pixelBuffer, options: [:])
            try! handler.perform([request!])
        }
    }
}
