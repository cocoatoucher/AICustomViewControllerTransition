//
//  PanToViewModalViewController.swift
//  Example
//
//  Created by cocoatoucher on 18/07/16.
//  Copyright © 2016 cocoatoucher. All rights reserved.
//

import UIKit
import AICustomViewControllerTransition

class PanToViewTransitionViewController: UIViewController {
	
	// View for user to drag an display the modal view controller
	@IBOutlet weak var panView: UIView!
	// Create a percent driven interactive transitioning delegate
	var customTransitioningDelegate: InteractiveTransitioningDelegate = InteractiveTransitioningDelegate()
	lazy var detailViewController: ModalViewController = {
		let vc = self.storyboard?.instantiateViewControllerWithIdentifier("detailViewController") as! ModalViewController
		// In this example, view controller can only be dismissed automatically
		vc.isPanIndicatorHidden = true
		vc.modalPresentationStyle = .Custom
		vc.transitioningDelegate = self.customTransitioningDelegate
		return vc
	}()
	// Keep track of pan ratio for transition animation
	var lastPanRatio: CGFloat = 0.0
	var panViewOriginalCenter = CGPointZero
	let panRatioThreshold: CGFloat = 0.3
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		customTransitioningDelegate.transitionPresent = { [weak self] (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, isInteractive: Bool, isInteractiveTransitionCancelled: Bool, completion: () -> Void) in
			
			guard let weakSelf = self else {
				return
			}
			
			var panViewEndFrame = weakSelf.panView.frame
			// If transition is interactive only the final values below will be used
			if (!isInteractive) {
				panViewEndFrame.origin.y = -CGRectGetHeight(panViewEndFrame)
				
				// Move modalViewController to the end of pan view
				toViewController.view.frame = CGRectMake(0, CGRectGetMaxY(containerView.bounds), CGRectGetWidth(containerView.bounds), CGRectGetHeight(containerView.bounds))
			}
			
			UIView.animateWithDuration(defaultTransitionAnimationDuration, animations: {
				// Move view controller to cover the screen
				toViewController.view.frame = containerView.bounds
				// If transition is interactive, it will be moved by pan gesture recognizer
				if (!isInteractive) {
					weakSelf.panView.frame = panViewEndFrame
				}
				
				}, completion: { (finished) in
					completion()
			})
		}
		
		customTransitioningDelegate.transitionDismiss = { [weak self] (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, isInteractive: Bool, isInteractiveTransitionCancelled: Bool, completion: () -> Void) in
			
			guard let weakSelf = self else {
				return
			}
			
			let endFrame = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(containerView.bounds))
			var panViewEndFrame = weakSelf.panView.frame
			panViewEndFrame.origin.y = CGRectGetHeight(weakSelf.view.bounds) - CGRectGetHeight(panViewEndFrame)
			
			UIView.animateWithDuration(defaultTransitionAnimationDuration, animations: {
				// Move modalViewController to out of the screen
				fromViewController.view.frame = endFrame
				// Move pan view to the bottom of the screen
				weakSelf.panView.frame = panViewEndFrame
				
				}, completion: { (finished) in
					completion()
			})
		}
		
		customTransitioningDelegate.transitionPercentPresent = {[weak self] (fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) in
			
			guard let weakSelf = self else {
				return
			}
			
			let verticalMoveAmount = CGRectGetHeight(weakSelf.view.bounds) - (CGRectGetHeight(weakSelf.view.bounds) * percentage)
			
			toViewController.view.frame = CGRectMake(0, verticalMoveAmount, CGRectGetWidth(containerView.bounds), CGRectGetHeight(containerView.bounds))
			
			toViewController.view.backgroundColor = UIColor(red: percentage, green: 1, blue: percentage, alpha: 1)
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	override func viewWillAppear(animated: Bool) {
		super.viewWillAppear(animated)
		
		self.navigationController!.setNavigationBarHidden(true, animated: true)
	}
	
	@IBAction func handlePan(panGestureRecognizer: UIPanGestureRecognizer) {
		
		if (panGestureRecognizer.state == .Began) {
			// Keep track of pan view's center
			self.panViewOriginalCenter = self.panView.center
			
			// Begin presenting in an interactive way
			self.customTransitioningDelegate.beginPresenting(viewController: self.detailViewController, fromViewController: self)
		} else if (panGestureRecognizer.state == .Changed) {
			let translatedPoint = panGestureRecognizer.translationInView(self.view)
			// Move pan view, alternatively this can be moved within transitioning delegate's animation closure
			self.panView.center = CGPointMake(self.panViewOriginalCenter.x, self.panViewOriginalCenter.y + translatedPoint.y)
			
			// Keep track of last pan ratio
			self.lastPanRatio = maximumInteractiveTransitionPercentage - ((self.panView.frame.origin.y + self.panView.frame.size.height) / CGRectGetHeight(self.view.bounds))
			// Update interactive transition percentage
			self.customTransitioningDelegate.updateInteractiveTransition(self.lastPanRatio)
		} else if (panGestureRecognizer.state == .Ended || panGestureRecognizer.state == .Failed || panGestureRecognizer.state == .Cancelled) {
			
			let completed = (self.lastPanRatio > panRatioThreshold)
			// Finalize the interactive transition
			self.customTransitioningDelegate.finalizeInteractiveTransition(isTransitionCompleted: completed)
			
			// Move the pan view either to out and top of the screen or bottom of the screen
			// Alternatively, this can be done in transitionPresent and transitionDismiss animation closures
			var panViewFrame = self.panView.frame
			UIView.animateWithDuration(defaultTransitionAnimationDuration, animations: {
				if !completed {
					panViewFrame.origin.y = CGRectGetHeight(self.view.bounds) - CGRectGetHeight(panViewFrame)
				} else {
					panViewFrame.origin.y =  -CGRectGetHeight(panViewFrame)
				}
				self.panView.frame = panViewFrame
			})
		}
	}
	
	@IBAction func simplePresentAction(sender: AnyObject) {
		// When user only taps the button, modalViewController is presented as usual
		self.presentViewController(self.detailViewController, animated: true, completion: nil)
	}
	
	@IBAction func backAction(sender: AnyObject) {
		self.navigationController?.popViewControllerAnimated(true)
		self.navigationController!.setNavigationBarHidden(false, animated: true)
	}

}
