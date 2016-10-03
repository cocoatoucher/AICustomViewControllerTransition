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
		let vc = self.storyboard?.instantiateViewController(withIdentifier: "detailViewController") as! ModalViewController
		// In this example, view controller can only be dismissed automatically
		vc.isPanIndicatorHidden = true
		vc.modalPresentationStyle = .custom
		vc.transitioningDelegate = self.customTransitioningDelegate
		return vc
	}()
	// Keep track of pan ratio for transition animation
	var lastPanRatio: CGFloat = 0.0
	var panViewOriginalCenter = CGPoint.zero
	let panRatioThreshold: CGFloat = 0.3
	
    override func viewDidLoad() {
        super.viewDidLoad()
		
		customTransitioningDelegate.transitionPresent = { [weak self] (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: @escaping () -> Void) in
			
			guard let weakSelf = self else {
				return
			}
			
			var panViewEndFrame = weakSelf.panView.frame
			// If transition is interactive only the final values below will be used
			if case .simple = transitionType {
				panViewEndFrame.origin.y = -panViewEndFrame.height
				
				// Move modalViewController to the end of pan view
				toViewController.view.frame = CGRect(x: 0, y: containerView.bounds.maxY, width: containerView.bounds.width, height: containerView.bounds.height)
			}
			
			UIView.animate(withDuration: defaultTransitionAnimationDuration, animations: {
				// Move view controller to cover the screen
				toViewController.view.frame = containerView.bounds
				// If transition is interactive, it will be moved by pan gesture recognizer
				if case .simple = transitionType {
					weakSelf.panView.frame = panViewEndFrame
				}
				
				}, completion: { (finished) in
					completion()
			})
		}
		
		customTransitioningDelegate.transitionDismiss = { [weak self] (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: @escaping () -> Void) in
			
			guard let weakSelf = self else {
				return
			}
			
			let endFrame = containerView.bounds.offsetBy(dx: 0, dy: containerView.bounds.height)
			var panViewEndFrame = weakSelf.panView.frame
			panViewEndFrame.origin.y = weakSelf.view.bounds.height - panViewEndFrame.height
			
			UIView.animate(withDuration: defaultTransitionAnimationDuration, animations: {
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
			
			let verticalMoveAmount = weakSelf.view.bounds.height - (weakSelf.view.bounds.height * percentage)
			
			toViewController.view.frame = CGRect(x: 0, y: verticalMoveAmount, width: containerView.bounds.width, height: containerView.bounds.height)
			
			toViewController.view.backgroundColor = UIColor(red: percentage, green: 1, blue: percentage, alpha: 1)
		}
    }

    override func didReceiveMemoryWarning() {
        super.didReceiveMemoryWarning()
        // Dispose of any resources that can be recreated.
    }
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		self.navigationController!.setNavigationBarHidden(true, animated: true)
	}
	
	@IBAction func handlePan(_ panGestureRecognizer: UIPanGestureRecognizer) {
		
		if (panGestureRecognizer.state == .began) {
			// Keep track of pan view's center
			self.panViewOriginalCenter = self.panView.center
			
			// Begin presenting in an interactive way
			self.customTransitioningDelegate.beginPresenting(viewController: self.detailViewController, fromViewController: self)
		} else if (panGestureRecognizer.state == .changed) {
			let translatedPoint = panGestureRecognizer.translation(in: self.view)
			// Move pan view, alternatively this can be moved within transitioning delegate's animation closure
			self.panView.center = CGPoint(x: self.panViewOriginalCenter.x, y: self.panViewOriginalCenter.y + translatedPoint.y)
			
			// Keep track of last pan ratio
			self.lastPanRatio = maximumInteractiveTransitionPercentage - ((self.panView.frame.origin.y + self.panView.frame.size.height) / (self.view.bounds).height)
			// Update interactive transition percentage
			self.customTransitioningDelegate.update(self.lastPanRatio)
		} else if (panGestureRecognizer.state == .ended || panGestureRecognizer.state == .failed || panGestureRecognizer.state == .cancelled) {
			
			let completed = (self.lastPanRatio > panRatioThreshold)
			// Finalize the interactive transition
			self.customTransitioningDelegate.finalizeInteractiveTransition(isTransitionCompleted: completed)
			
			// Move the pan view either to out and top of the screen or bottom of the screen
			// Alternatively, this can be done in transitionPresent and transitionDismiss animation closures
			var panViewFrame = self.panView.frame
			UIView.animate(withDuration: defaultTransitionAnimationDuration, animations: {
				if !completed {
					panViewFrame.origin.y = self.view.bounds.height - panViewFrame.height
				} else {
					panViewFrame.origin.y =  -panViewFrame.height
				}
				self.panView.frame = panViewFrame
			})
		}
	}
	
	@IBAction func simplePresentAction(_ sender: AnyObject) {
		// When user only taps the button, modalViewController is presented as usual
		self.present(self.detailViewController, animated: true, completion: nil)
	}
	
	@IBAction func backAction(_ sender: AnyObject) {
		_ = self.navigationController?.popViewController(animated: true)
		self.navigationController!.setNavigationBarHidden(false, animated: true)
	}

}
