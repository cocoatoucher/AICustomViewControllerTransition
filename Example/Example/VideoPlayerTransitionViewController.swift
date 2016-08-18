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
		let vc = self.storyboard?.instantiateViewControllerWithIdentifier("videoPlayerViewController") as! VideoPlayerModalViewController
		vc.modalPresentationStyle = .Custom
		vc.transitioningDelegate = self.customTransitioningDelegate
		// Pan gesture recognizer feedback from VideoPlayerModalViewController
		vc.handlePan = {(panGestureRecozgnizer) in
			
			let translatedPoint = panGestureRecozgnizer.translationInView(self.view)
			
			if (panGestureRecozgnizer.state == .Began) {
				
				self.customTransitioningDelegate.beginDismissing(viewController: vc)
				self.lastVideoPlayerOriginY = vc.view.frame.origin.y
				
			} else if (panGestureRecozgnizer.state == .Changed) {
				let ratio = max(min(((self.lastVideoPlayerOriginY + translatedPoint.y) / CGRectGetMinY(self.thumbnailVideoContainerView.frame)), 1), 0)
				
				// Store lastPanRatio for next callback
				self.lastPanRatio = ratio
				
				// Update percentage of interactive transition
				self.customTransitioningDelegate.updateInteractiveTransition(self.lastPanRatio)
			} else if (panGestureRecozgnizer.state == .Ended) {
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
		
		customTransitioningDelegate.transitionPresent = { [weak self] (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: () -> Void) in
			
			guard let weakSelf = self else {
				return
			}
			
			let videoPlayerViewController = toViewController as! VideoPlayerModalViewController
			
			if case .Simple = transitionType {
				if (weakSelf.videoPlayerViewControllerInitialFrame != nil) {
					videoPlayerViewController.view.frame = weakSelf.videoPlayerViewControllerInitialFrame!
					weakSelf.videoPlayerViewControllerInitialFrame = nil
				} else {
					videoPlayerViewController.view.frame = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(videoPlayerViewController.view.frame))
					videoPlayerViewController.backgroundView.alpha = 0.0
					videoPlayerViewController.dismissButton.alpha = 0.0
				}
			}
			
			UIView.animateWithDuration(defaultTransitionAnimationDuration, animations: {
				videoPlayerViewController.view.transform = CGAffineTransformIdentity
				videoPlayerViewController.view.frame = containerView.bounds
				videoPlayerViewController.backgroundView.alpha = 1.0
				videoPlayerViewController.dismissButton.alpha = 1.0
				
				}, completion: { (finished) in
					completion()
					// In order to disable user interaction with pan gesture recognizer
					// It is important to do this after completion block, since user interaction is enabled after view controller transition completes
					videoPlayerViewController.view.userInteractionEnabled = true
			})
		}
		
		customTransitioningDelegate.transitionDismiss = { [weak self] (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: () -> Void) in
			
			guard let weakSelf = self else {
				return
			}
			
			let videoPlayerViewController = fromViewController as! VideoPlayerModalViewController
			
			let finalTransform = CGAffineTransformMakeScale(CGRectGetWidth(weakSelf.thumbnailVideoContainerView.bounds) / CGRectGetWidth(videoPlayerViewController.view.bounds), CGRectGetHeight(weakSelf.thumbnailVideoContainerView.bounds) * 3 / CGRectGetHeight(videoPlayerViewController.view.bounds))
			
			UIView.animateWithDuration(defaultTransitionAnimationDuration, animations: {
				videoPlayerViewController.view.transform = finalTransform
				var finalRect = videoPlayerViewController.view.frame
				finalRect.origin.x = CGRectGetMinX(weakSelf.thumbnailVideoContainerView.frame)
				finalRect.origin.y = CGRectGetMinY(weakSelf.thumbnailVideoContainerView.frame)
				videoPlayerViewController.view.frame = finalRect
				
				videoPlayerViewController.backgroundView.alpha = 0.0
				videoPlayerViewController.dismissButton.alpha = 0.0
				
				}, completion: { (finished) in
					completion()
					
					videoPlayerViewController.view.userInteractionEnabled = false
					weakSelf.addChildViewController(videoPlayerViewController)
					
					var thumbnailRect = videoPlayerViewController.view.frame
					thumbnailRect.origin = CGPointZero
					videoPlayerViewController.view.frame = thumbnailRect
					
					weakSelf.thumbnailVideoContainerView.addSubview(fromViewController.view)
					fromViewController.didMoveToParentViewController(weakSelf)
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
			
			let startXScale = CGRectGetWidth(weakSelf.thumbnailVideoContainerView.bounds) / CGRectGetWidth(containerView.bounds)
			let startYScale = CGRectGetHeight(weakSelf.thumbnailVideoContainerView.bounds) * 3 / CGRectGetHeight(containerView.bounds)
			
			let xScale = startXScale + ((1 - startXScale) * percentage)
			let yScale = startYScale + ((1 - startYScale) * percentage)
			toViewController.view.transform = CGAffineTransformMakeScale(xScale, yScale)
			
			let startXPos = CGRectGetMinX(weakSelf.thumbnailVideoContainerView.frame)
			let startYPos = CGRectGetMinY(weakSelf.thumbnailVideoContainerView.frame)
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
			
			let finalXScale = CGRectGetWidth(weakSelf.thumbnailVideoContainerView.bounds) / CGRectGetWidth(videoPlayerViewController.view.bounds)
			let finalYScale = CGRectGetHeight(weakSelf.thumbnailVideoContainerView.bounds) * 3 / CGRectGetHeight(videoPlayerViewController.view.bounds)
			let xScale = 1 - (percentage * (1 - finalXScale))
			let yScale = 1 - (percentage * (1 - finalYScale))
			videoPlayerViewController.view.transform = CGAffineTransformMakeScale(xScale, yScale)
			
			let finalXPos = CGRectGetMinX(weakSelf.thumbnailVideoContainerView.frame)
			let finalYPos = CGRectGetMinY(weakSelf.thumbnailVideoContainerView.frame)
			let horizontalMove = min(CGRectGetMinX(weakSelf.thumbnailVideoContainerView.frame) * percentage, finalXPos)
			let verticalMove = min(CGRectGetMinY(weakSelf.thumbnailVideoContainerView.frame) * percentage, finalYPos)
			
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
	
	@IBAction func presentAction(sender: AnyObject) {
		if (self.videoPlayerViewController.parentViewController != nil) {
			self.videoPlayerViewControllerInitialFrame = self.thumbnailVideoContainerView.convertRect(self.videoPlayerViewController.view.frame, toView: self.view)
			self.videoPlayerViewController.removeFromParentViewController()
		}
		
		self.presentViewController(self.videoPlayerViewController, animated: true, completion: nil)
	}
	
	@IBAction func presentFromThumbnailAction(sender: AnyObject) {
		guard self.videoPlayerViewController.parentViewController != nil else {
			return
		}
		
		self.videoPlayerViewControllerInitialFrame = self.thumbnailVideoContainerView.convertRect(self.videoPlayerViewController.view.frame, toView: self.view)
		self.videoPlayerViewController.removeFromParentViewController()
		self.presentViewController(self.videoPlayerViewController, animated: true, completion: nil)
	}
	
	@IBAction func handlePresentPan(panGestureRecozgnizer: UIPanGestureRecognizer) {
		
		guard self.videoPlayerViewController.parentViewController != nil || self.customTransitioningDelegate.isPresenting else {
			return
		}
		
		let translatedPoint = panGestureRecozgnizer.translationInView(self.view)
		
		if (panGestureRecozgnizer.state == .Began) {
			
			self.videoPlayerViewControllerInitialFrame = self.thumbnailVideoContainerView.convertRect(self.videoPlayerViewController.view.frame, toView: self.view)
			self.videoPlayerViewController.removeFromParentViewController()
			
			self.customTransitioningDelegate.beginPresenting(viewController: self.videoPlayerViewController, fromViewController: self)
			
			self.videoPlayerViewControllerInitialFrame = self.thumbnailVideoContainerView.convertRect(self.videoPlayerViewController.view.frame, toView: self.view)
			
			self.lastVideoPlayerOriginY = self.videoPlayerViewControllerInitialFrame!.origin.y
			
		} else if (panGestureRecozgnizer.state == .Changed) {
			
			let ratio = max(min(((self.lastVideoPlayerOriginY + translatedPoint.y) / CGRectGetMinY(self.thumbnailVideoContainerView.frame)), 1), 0)
			
			// Store lastPanRatio for next callback
			self.lastPanRatio = 1 - ratio
			
			// Update percentage of interactive transition
			self.customTransitioningDelegate.updateInteractiveTransition(self.lastPanRatio)
		} else if (panGestureRecozgnizer.state == .Ended) {
			// If pan ratio exceeds the threshold then transition is completed, otherwise cancel dismissal and present the view controller again
			let completed = (self.lastPanRatio > self.panRatioThreshold) || (self.lastPanRatio < -self.panRatioThreshold)
			self.customTransitioningDelegate.finalizeInteractiveTransition(isTransitionCompleted: completed)
		}
	}
	
}
