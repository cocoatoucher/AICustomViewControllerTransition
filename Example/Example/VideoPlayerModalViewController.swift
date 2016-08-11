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
	
	override func layoutSublayersOfLayer(layer: CALayer) {
		super.layoutSublayersOfLayer(layer)
		
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
	
	var handlePan: ((panGestureRecognizer: UIPanGestureRecognizer) -> Void)?
	
	let videoPlayer = AVPlayer(URL: NSURL.fileURLWithPath(NSBundle.mainBundle().pathForResource("video", ofType: "mp4")!))
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		let videoPlayerLayer = AVPlayerLayer(player: self.videoPlayer)
		videoPlayerLayer.videoGravity = AVLayerVideoGravityResize;
		self.videoView.videoPlayerLayer = videoPlayerLayer
		self.videoView.layer.addSublayer(videoPlayerLayer)
		self.videoPlayer.play()
		
		// Repeat the video forever
		self.videoPlayer.actionAtItemEnd = .None
		NSNotificationCenter.defaultCenter().addObserver(self, selector: #selector(VideoPlayerModalViewController.playerItemDidReachEnd(_:)), name: AVPlayerItemDidPlayToEndTimeNotification, object: self.videoPlayer.currentItem)
    }
	
	func playerItemDidReachEnd(notification: NSNotification) {
		self.videoPlayer.seekToTime(kCMTimeZero)
	}

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
    
	@IBAction func handlePan(sender: UIPanGestureRecognizer) {
		self.handlePan?(panGestureRecognizer: sender)
	}
	
	@IBAction func dismissAction(sender: AnyObject) {
		self.dismissViewControllerAnimated(true, completion: nil)
	}
}
