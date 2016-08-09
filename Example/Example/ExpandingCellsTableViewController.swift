//
//  ExpandingTableViewController.swift
//  Example
//
//  Created by cocoatoucher on 10/07/16.
//  Copyright © 2016 cocoatoucher. All rights reserved.
//

import UIKit
import AICustomViewControllerTransition

class ExpandingCellsTableViewController: UIViewController, UITableViewDelegate, UITableViewDataSource {
	
	@IBOutlet weak var tableView: UITableView!
	
	// Create a transitioning delegate for percent driven interactive transition
	var customTransitioningDelegate: InteractiveTransitioningDelegate = InteractiveTransitioningDelegate()
	
	// Store selected cell's index path during transition
	var selectedCellIndexPath: NSIndexPath?
	
	// Using a transitionView to replicate cell's inner view during transition
	// In order to do that for your own custom cells, implement cell content as a seperate class or optionally a separate .xib file, then place the same view above your table view
	@IBOutlet weak var transitionView: UIView!
	@IBOutlet weak var transitionImageView: UIImageView!
	@IBOutlet weak var transitionViewTopSpace: NSLayoutConstraint!
	
	let panRatioThreshold: CGFloat = 0.3
	// Storing pan ratio for keeping track of progress with pan gesture recognizer
	var lastPanRatio: CGFloat = 0.0
	
	lazy var detailViewController: ModalViewController = {
		let vc = self.storyboard?.instantiateViewControllerWithIdentifier("detailViewController") as! ModalViewController
		vc.modalPresentationStyle = .Custom
		vc.transitioningDelegate = self.customTransitioningDelegate
		// Pan gesture recognizer feedback from detailViewController's view is captured via this callback closure
		vc.dismissCallback = {(panGestureRecozgnizer, translatedPoint) in
			
			if (panGestureRecozgnizer.state == .Began) {
				// Begin dismissing view controller
				self.customTransitioningDelegate.beginDismissing(viewController: vc)
			} else if (panGestureRecozgnizer.state == .Changed) {
				let ratio = (translatedPoint.y) / CGRectGetHeight(vc.view.bounds)
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
	
	override func viewDidLoad() {
		super.viewDidLoad()
		
		// Animate presentation transition
		customTransitioningDelegate.transitionPresent = { [weak self] (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, isInteractive: Bool, isInteractiveTransitionCancelled: Bool, completion: () -> Void) in
			
			guard let weakSelf = self else {
				return
			}
			
			guard let indexPath = weakSelf.selectedCellIndexPath else {
				return
			}
			
			guard let cell = weakSelf.tableView.cellForRowAtIndexPath(indexPath) as? TableViewCell else {
				return
			}
			
			let originalFrame = containerView.convertRect(cell.innerView.frame, fromView: cell.innerView.superview)
			
			// If interactive transition is cancelled, there is no need to setup the transitionView and reset modalViewController's frame, since the final values will be used to present back to the previous state
			if !isInteractiveTransitionCancelled {
				
				// Move transitionView in the same place with the cell
				weakSelf.transitionViewTopSpace.constant = CGRectGetMinY(originalFrame)
				weakSelf.view.layoutIfNeeded()
				
				// Start replicating the cell's inner view and hide the cell's inner view
				weakSelf.transitionView.hidden = false
				cell.innerView.hidden = true
				weakSelf.transitionImageView.image = cell.thumbnail.image
				
				// Replicate cell in modalViewController's header image
				(toViewController as! ModalViewController).headerImageView.image = cell.thumbnail.image
				
				// Set initial opacity to 0
				toViewController.view.alpha = 0.0
				
				// Set initial frame to right above the cell, aligning top
				toViewController.view.frame = CGRectMake(0, CGRectGetMinY(originalFrame), CGRectGetWidth(containerView.bounds), CGRectGetHeight(containerView.bounds))
			}
			
			// Move transitionView to top of the screen
			weakSelf.transitionViewTopSpace.constant = 0.0
			weakSelf.view.setNeedsUpdateConstraints()
			
			UIView.animateWithDuration(0.5, delay:0.0, options: .CurveEaseInOut, animations: {
				// Animate the transitionView
				weakSelf.view.layoutIfNeeded()
				
				// Animate modal view controller to cover the screen
				toViewController.view.frame = containerView.bounds
				// Make modal view controller visible
				toViewController.view.alpha = 1.0
				
				}, completion: { (finished) in
					completion()
			})
		}
		
		customTransitioningDelegate.transitionDismiss = { [weak self] (fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, isInteractive: Bool, isInteractiveTransitionCancelled: Bool, completion: () -> Void) in
			
			guard let weakSelf = self else {
				return
			}
			
			guard let indexPath = weakSelf.selectedCellIndexPath else {
				return
			}
			
			guard let cell = weakSelf.tableView.cellForRowAtIndexPath(indexPath) as? TableViewCell else {
				return
			}
			
			let originalFrame = containerView.convertRect(cell.frame, fromView:cell.superview)
			// Calculate the vertical amount to move cell's inner view and modalViewController's view
			let verticalMoveAmount = CGRectGetMinY(originalFrame)
			
			// Move cell's inner view to right above the cell
			weakSelf.transitionViewTopSpace.constant = verticalMoveAmount
			weakSelf.view.setNeedsUpdateConstraints()
			
			UIView.animateWithDuration(0.5, animations: {
				
				weakSelf.view.layoutIfNeeded()
				
				// Move modalViewController to right above the cell
				fromViewController.view.frame = CGRectMake(0, verticalMoveAmount + CGRectGetMinY(containerView.frame), CGRectGetWidth(containerView.bounds), CGRectGetHeight(containerView.bounds))
				// Make modalViewController hidden
				fromViewController.view.alpha = 0.0
				
				}, completion: { (finished) in
					// Make cell's innerView visible again
					// Hide transitionView
					cell.innerView.hidden = false
					weakSelf.transitionView.hidden = true
					
					completion()
			})
		}
		
		customTransitioningDelegate.transitionPercentDismiss = {[weak self] (fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) in
			
			guard let weakSelf = self else {
				return
			}
			
			guard let indexPath = weakSelf.selectedCellIndexPath else {
				return
			}
			
			guard let cell = weakSelf.tableView.cellForRowAtIndexPath(indexPath) as? TableViewCell else {
				return
			}
			
			let originalFrame = containerView.convertRect(cell.frame, fromView:cell.superview)
			// Calculate the vertical amount to move cell's inner view and modalViewController's view
			let verticalMoveAmount = CGRectGetMinY(originalFrame) * percentage
			
			// Move transitionView by the vertical move amount
			weakSelf.transitionViewTopSpace.constant = verticalMoveAmount
			weakSelf.view.layoutIfNeeded()
			
			// Move modalViewController's view by the vertical move amount
			fromViewController.view.frame = CGRectMake(0, verticalMoveAmount, CGRectGetWidth(containerView.bounds), CGRectGetHeight(containerView.bounds))
			
			// Alter modalViewController's opacity
			fromViewController.view.alpha = maximumInteractiveTransitionPercentage - percentage
		}
	}
	
	override func didReceiveMemoryWarning() {
		super.didReceiveMemoryWarning()
		// Dispose of any resources that can be recreated.
	}
	
	// MARK: - Table view data source
	
	func numberOfSectionsInTableView(tableView: UITableView) -> Int {
		return 1
	}
	
	func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		return 7
	}
	
	func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
		let cell = tableView.dequeueReusableCellWithIdentifier("reuseIdentifier", forIndexPath: indexPath) as! TableViewCell
		
		cell.thumbnail.image = UIImage(named: "\(indexPath.row)")
		
		return cell
	}
	
	func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
		
		// Store selected cell's index path during transition
		self.selectedCellIndexPath = indexPath
		
		// Present view controller as usual
		// In this example, modal view controller can be dismissed either as usual(dismissViewController) or via user interaction via pan gesture recognizer
		// There seems to be a bug in SDK, see here: http://openradar.appspot.com/19563577
		// Calling presentViewController() within didSelectRowAtIndexPath() gets even slower with UIViewControllerAnimatedTransitioning
		// Temporary solution is dispatch_async() with main queue
		dispatch_async(dispatch_get_main_queue()) {
			self.presentViewController(self.detailViewController, animated: true, completion: nil)
		}
	}
	
}
