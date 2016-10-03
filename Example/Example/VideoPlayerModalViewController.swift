//
//  VideoPlayerModalViewController.swift
//  Example
//
//  Created by cocoatoucher on 10/08/16.
//  Copyright © 2016 cocoatoucher. All rights reserved.
//

import UIKit
import AVFoundation

class VideoView: UIView {
	
	var videoPlayerLayer: AVPlayerLayer?
	
	override func layoutSublayers(of layer: CALayer) {
		super.layoutSublayers(of: layer)
		
		if (self.videoPlayerLayer != nil) {
			self.videoPlayerLayer?.frame = self.bounds
		}
	}
}

class VideoPlayerModalViewController: UIViewController {
	
	@IBOutlet weak var videoView: VideoView!
	@IBOutlet weak var videoViewHeightConstraint: NSLayoutConstraint!
	@IBOutlet weak var videoViewAtBottomConstraint: NSLayoutConstraint!
	@IBOutlet weak var backgroundView: UIView!
	@IBOutlet weak var dismissButton: UIButton!
	
	var handlePan: ((_ panGestureRecognizer: UIPanGestureRecognizer) -> Void)?
	
	let videoPlayer = AVPlayer(url: URL(fileURLWithPath: Bundle.main.path(forResource: "video", ofType: "mp4")!))
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		let videoPlayerLayer = AVPlayerLayer(player: self.videoPlayer)
		videoPlayerLayer.videoGravity = AVLayerVideoGravityResize;
		self.videoView.videoPlayerLayer = videoPlayerLayer
		self.videoView.layer.addSublayer(videoPlayerLayer)
		self.videoPlayer.play()
		
		// Repeat the video forever
		self.videoPlayer.actionAtItemEnd = .none
		NotificationCenter.default.addObserver(self, selector: #selector(VideoPlayerModalViewController.playerItemDidReachEnd(_:)), name: NSNotification.Name.AVPlayerItemDidPlayToEndTime, object: self.videoPlayer.currentItem)
    }
	
	func playerItemDidReachEnd(_ notification: Notification) {
		self.videoPlayer.seek(to: kCMTimeZero)
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
	@IBAction func handlePan(_ sender: UIPanGestureRecognizer) {
		self.handlePan?(sender)
	}
	
	@IBAction func dismissAction(_ sender: AnyObject) {
		self.dismiss(animated: true, completion: nil)
	}
}
