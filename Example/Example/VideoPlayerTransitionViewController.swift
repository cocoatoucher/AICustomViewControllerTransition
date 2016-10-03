//
//  VideoPlayerTransitionViewController.swift
//  Example
//
//  Created by cocoatoucher on 10/08/16.
//  Copyright © 2016 cocoatoucher. All rights reserved.
//

import UIKit
import AICustomViewControllerTransition

class VideoPlayerTransitionViewController: UIViewController {
	
	// Container view to display video player modal view controller when minimized
	@IBOutlet weak var thumbnailVideoContainerView: UIView!
	
	// Create an interactive transitioning delegate
	let customTransitioningDelegate: InteractiveTransitioningDelegate = InteractiveTransitioningDelegate()
	
	lazy var videoPlayerViewController: VideoPlayerModalViewController = {
		let vc = self.storyboard?.instantiateViewController(withIdentifier: "videoPlayerViewController") as! VideoPlayerModalViewController
		vc.modalPresentationStyle = .custom
		vc.transitioningDelegate = self.customTransitioningDelegate
		// Pan gesture recognizer feedback from VideoPlayerModalViewController
		vc.handlePan = {(panGestureRecozgnizer) in
			
			let translatedPoint = panGestureRecozgnizer.translation(in: self.view)
			
			if (panGestureRecozgnizer.state == .began) {
				
				self.customTransitioningDelegate.beginDismissing(viewController: vc)
				self.lastVideoPlayerOriginY = vc.view.frame.origin.y
				
			} else if (panGestureRecozgnizer.state == .changed) {
				let ratio = max(min(((self.lastVideoPlayerOriginY + translatedPoint.y) / self.thumbnailVideoContainerView.frame.minY), 1), 0)
				
				// Store lastPanRatio for next callback
				self.lastPanRatio = ratio
				
				// Update percentage of interactive transition
				self.customTransitioningDelegate.update(self.lastPanRatio)
			} else if (panGestureRecozgnizer.state == .ended) {
				// If pan ratio exceeds the threshold then transition is completed, otherwise cancel dismissal and present the view controller again
				let completed = (self.lastPanRatio > self.panRatioThreshold) || (self.lastPanRatio < -self.panRatioThreshold)
				self.customTransitioningDelegate.finalizeInteractiveTransition(isTransitionCompleted: completed)
			}
		}
		return vc
	}()
	
	let panRatioThreshold: CGFloat = 0.3
	var lastPanRatio: CGFloat = 0.0
	var lastVideoPlayerOriginY: CGFloat = 0.0
	var videoPlayerViewControllerInitialFrame: CGRect?
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		customTransitioningDelegate.transitionPresent = { [weak self] (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: @escaping () -> Void) in
			
			guard let weakSelf = self else {
				return
			}
			
			let videoPlayerViewController = toViewController as! VideoPlayerModalViewController
			
			if case .simple = transitionType {
				if (weakSelf.videoPlayerViewControllerInitialFrame != nil) {
					videoPlayerViewController.view.frame = weakSelf.videoPlayerViewControllerInitialFrame!
					weakSelf.videoPlayerViewControllerInitialFrame = nil
				} else {
					videoPlayerViewController.view.frame = containerView.bounds.offsetBy(dx: 0, dy: videoPlayerViewController.view.frame.height)
					videoPlayerViewController.backgroundView.alpha = 0.0
					videoPlayerViewController.dismissButton.alpha = 0.0
				}
			}
			
			UIView.animate(withDuration: defaultTransitionAnimationDuration, animations: {
				videoPlayerViewController.view.transform = CGAffineTransform.identity
				videoPlayerViewController.view.frame = containerView.bounds
				videoPlayerViewController.backgroundView.alpha = 1.0
				videoPlayerViewController.dismissButton.alpha = 1.0
				
				}, completion: { (finished) in
					completion()
					// In order to disable user interaction with pan gesture recognizer
					// It is important to do this after completion block, since user interaction is enabled after view controller transition completes
					videoPlayerViewController.view.isUserInteractionEnabled = true
			})
		}
		
		customTransitioningDelegate.transitionDismiss = { [weak self] (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: @escaping () -> Void) in
			
			guard let weakSelf = self else {
				return
			}
			
			let videoPlayerViewController = fromViewController as! VideoPlayerModalViewController
			
			let finalTransform = CGAffineTransform(scaleX: weakSelf.thumbnailVideoContainerView.bounds.width / videoPlayerViewController.view.bounds.width, y: weakSelf.thumbnailVideoContainerView.bounds.height * 3 / videoPlayerViewController.view.bounds.height)
			
			UIView.animate(withDuration: defaultTransitionAnimationDuration, animations: {
				videoPlayerViewController.view.transform = finalTransform
				var finalRect = videoPlayerViewController.view.frame
				finalRect.origin.x = weakSelf.thumbnailVideoContainerView.frame.minX
				finalRect.origin.y = weakSelf.thumbnailVideoContainerView.frame.minY
				videoPlayerViewController.view.frame = finalRect
				
				videoPlayerViewController.backgroundView.alpha = 0.0
				videoPlayerViewController.dismissButton.alpha = 0.0
				
				}, completion: { (finished) in
					completion()
					
					videoPlayerViewController.view.isUserInteractionEnabled = false
					weakSelf.addChildViewController(videoPlayerViewController)
					
					var thumbnailRect = videoPlayerViewController.view.frame
					thumbnailRect.origin = CGPoint.zero
					videoPlayerViewController.view.frame = thumbnailRect
					
					weakSelf.thumbnailVideoContainerView.addSubview(fromViewController.view)
					fromViewController.didMove(toParentViewController: weakSelf)
			})
		}
		
		customTransitioningDelegate.transitionPercentPresent = {[weak self] (fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) in
			
			guard let weakSelf = self else {
				return
			}
			
			let videoPlayerViewController = toViewController as! VideoPlayerModalViewController
			
			if (weakSelf.videoPlayerViewControllerInitialFrame != nil) {
				weakSelf.videoPlayerViewController.view.frame = weakSelf.videoPlayerViewControllerInitialFrame!
				weakSelf.videoPlayerViewControllerInitialFrame = nil
			}
			
			let startXScale = weakSelf.thumbnailVideoContainerView.bounds.width / containerView.bounds.width
			let startYScale = weakSelf.thumbnailVideoContainerView.bounds.height * 3 / containerView.bounds.height
			
			let xScale = startXScale + ((1 - startXScale) * percentage)
			let yScale = startYScale + ((1 - startYScale) * percentage)
			toViewController.view.transform = CGAffineTransform(scaleX: xScale, y: yScale)
			
			let startXPos = weakSelf.thumbnailVideoContainerView.frame.minX
			let startYPos = weakSelf.thumbnailVideoContainerView.frame.minY
			let horizontalMove = startXPos - (startXPos * percentage)
			let verticalMove = startYPos - (startYPos * percentage)
			
			var finalRect = toViewController.view.frame
			finalRect.origin.x = horizontalMove
			finalRect.origin.y = verticalMove
			toViewController.view.frame = finalRect
			
			videoPlayerViewController.backgroundView.alpha = percentage
			videoPlayerViewController.dismissButton.alpha = percentage
		}
		
		customTransitioningDelegate.transitionPercentDismiss = {[weak self] (fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) in
			
			guard let weakSelf = self else {
				return
			}
			
			let videoPlayerViewController = fromViewController as! VideoPlayerModalViewController
			
			let finalXScale = weakSelf.thumbnailVideoContainerView.bounds.width / videoPlayerViewController.view.bounds.width
			let finalYScale = weakSelf.thumbnailVideoContainerView.bounds.height * 3 / videoPlayerViewController.view.bounds.height
			let xScale = 1 - (percentage * (1 - finalXScale))
			let yScale = 1 - (percentage * (1 - finalYScale))
			videoPlayerViewController.view.transform = CGAffineTransform(scaleX: xScale, y: yScale)
			
			let finalXPos = weakSelf.thumbnailVideoContainerView.frame.minX
			let finalYPos = weakSelf.thumbnailVideoContainerView.frame.minY
			let horizontalMove = min(weakSelf.thumbnailVideoContainerView.frame.minX * percentage, finalXPos)
			let verticalMove = min(weakSelf.thumbnailVideoContainerView.frame.minY * percentage, finalYPos)
			
			var finalRect = videoPlayerViewController.view.frame
			finalRect.origin.x = horizontalMove
			finalRect.origin.y = verticalMove
			videoPlayerViewController.view.frame = finalRect
			
			videoPlayerViewController.backgroundView.alpha = 1 - percentage
			videoPlayerViewController.dismissButton.alpha = 1 - percentage
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	@IBAction func presentAction(_ sender: AnyObject) {
		if (self.videoPlayerViewController.parent != nil) {
			self.videoPlayerViewControllerInitialFrame = self.thumbnailVideoContainerView.convert(self.videoPlayerViewController.view.frame, to: self.view)
			self.videoPlayerViewController.removeFromParentViewController()
		}
		
		self.present(self.videoPlayerViewController, animated: true, completion: nil)
	}
	
	@IBAction func presentFromThumbnailAction(_ sender: AnyObject) {
		guard self.videoPlayerViewController.parent != nil else {
			return
		}
		
		self.videoPlayerViewControllerInitialFrame = self.thumbnailVideoContainerView.convert(self.videoPlayerViewController.view.frame, to: self.view)
		self.videoPlayerViewController.removeFromParentViewController()
		self.present(self.videoPlayerViewController, animated: true, completion: nil)
	}
	
	@IBAction func handlePresentPan(_ panGestureRecozgnizer: UIPanGestureRecognizer) {
		
		guard self.videoPlayerViewController.parent != nil || self.customTransitioningDelegate.isPresenting else {
			return
		}
		
		let translatedPoint = panGestureRecozgnizer.translation(in: self.view)
		
		if (panGestureRecozgnizer.state == .began) {
			
			self.videoPlayerViewControllerInitialFrame = self.thumbnailVideoContainerView.convert(self.videoPlayerViewController.view.frame, to: self.view)
			self.videoPlayerViewController.removeFromParentViewController()
			
			self.customTransitioningDelegate.beginPresenting(viewController: self.videoPlayerViewController, fromViewController: self)
			
			self.videoPlayerViewControllerInitialFrame = self.thumbnailVideoContainerView.convert(self.videoPlayerViewController.view.frame, to: self.view)
			
			self.lastVideoPlayerOriginY = self.videoPlayerViewControllerInitialFrame!.origin.y
			
		} else if (panGestureRecozgnizer.state == .changed) {
			
			let ratio = max(min(((self.lastVideoPlayerOriginY + translatedPoint.y) / self.thumbnailVideoContainerView.frame.minY), 1), 0)
			
			// Store lastPanRatio for next callback
			self.lastPanRatio = 1 - ratio
			
			// Update percentage of interactive transition
			self.customTransitioningDelegate.update(self.lastPanRatio)
		} else if (panGestureRecozgnizer.state == .ended) {
			// If pan ratio exceeds the threshold then transition is completed, otherwise cancel dismissal and present the view controller again
			let completed = (self.lastPanRatio > self.panRatioThreshold) || (self.lastPanRatio < -self.panRatioThreshold)
			self.customTransitioningDelegate.finalizeInteractiveTransition(isTransitionCompleted: completed)
		}
	}
	
}
