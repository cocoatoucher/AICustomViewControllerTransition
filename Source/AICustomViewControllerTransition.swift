//
//  AICustomViewControllerTransition.swift
//  AICustomViewControllerTransition
//
//  Created by cocoatoucher on 09/07/16.
//  Copyright © 2016 cocoatoucher. All rights reserved.
//

import UIKit

/**
	Transition handling closure

	- parameter fromViewController: Currently visible view controller
	- parameter toViewController: View controller to be displayed after the transition
	- parameter containerView: Transition view which will contain both fromViewController and toViewController's views. Place any temporary animated views on this view. During animation fromViewController and toViewController's views are subviews of containerView.
	- parameter isInteractive: true if the transition is interactive, false otherwise
	- parameter isInteractiveTransitionCancelled: true if the interactive transition is cancelled, that the transition is interrupted and will return to its previous state, false otherwise. Use this to decide if you need to reset your animated views to initial state either as fully presented or fully dismissed, depending on which closure property is called
	- parameter completion: This closure should be called at the end of your transition animation to finalize the transition
*/
public typealias TransitionViewController = ((fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, isInteractive: Bool, isInteractiveTransitionCancelled: Bool, completion: () -> Void) -> Void)

/**
	Interactive transition percentage handling closure

	- parameter fromViewController: Currently visible view controller
	- parameter toViewController: View controller to display
	- parameter percentage: Percentage of the transition phase. Ranges from 0 to 1.0 (maximumInteractiveTransitionPercentage)
	- parameter containerView: Transition view which will contain both fromViewController and toViewController's views. Place any temporary animated views on this view
*/
public typealias PercentTransitionViewController = ((fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) -> Void)

/**
	Animation duration used within default transition animation closure values
	0.3
*/
public let defaultTransitionAnimationDuration: NSTimeInterval = 0.3
/**
	Maximum percentage value used for percent driven interactive transition
	1.0
*/
public let maximumInteractiveTransitionPercentage: CGFloat = 1.0
/**
	Minimum percentage value used for percent driven interactive transition
	0.0
*/
public let minimumTransitionPercentage: CGFloat = 0.0

/**
	Transition directions

	- None: No transition
	- Presenting: Transitioning delegate is presenting a view controller
	- Dismissing: Transitioning delegate is dismissing a view controller
*/
private enum TransitionDirection {
	case None, Presenting, Dismissing
}

//MARK: - TransitionState
/**
	Transition states

	- Start: Interactive transition has started either presenting or dismissing which can either be interactive or simple
	- InteractivePercentage: State of an interactive transition, either presentation or dismissal, is changing percentage
	- Finish: Interactive transition has completed either presenting or dismissing which can either be interactive or simple
	- Cancel: Interactive transition has cancelled either presenting or dismissing a view controller in an interactive way
*/
private enum TransitionState {
	case None, Start(isInteractive: Bool), InteractivePercentage(isInteractive: Bool, percentage: CGFloat), Finish(isInteractive: Bool), Cancel(isInteractive: Bool)
	
	var isNone: Bool {
		switch self {
		case .None:
			return true
		default:
			return false
		}
	}
	
	var isInteractive: Bool {
		switch self {
		case .Start(let isInteractive):
			return isInteractive
		case .InteractivePercentage(let isInteractive, _):
			return isInteractive
		case .Finish(let isInteractive):
			return isInteractive
		case .Cancel(let isInteractive):
			return isInteractive
		default:
			return false
		}
	}
	
	var percentage: CGFloat {
		switch self {
		case .InteractivePercentage(_, let percentage):
			return percentage
		default:
			return 0.0
		}
	}
	
	/**
		A transition state is considered percent driven in two cases
		1. Transition has started interactively, with percentage 0
		2. Transition is progressing with changing percentage in interactive state
	*/
	var isPercentDriven: Bool {
		switch self {
		case .Start(let isInteractive) where isInteractive:
			return true
		case .InteractivePercentage(_):
			return true
		default:
			return false
		}
	}
	
	var didTransitionStart: Bool {
		switch self {
		case .Start(_):
			return true
		default:
			return false
		}
	}
	
	var didTransitionEnd: Bool {
		switch self {
		case .Finish(_), .Cancel(_):
			return true
		default:
			return false
		}
	}
	
	var isInteractiveTransitionCancelled: Bool {
		switch self {
		case .Cancel(_):
			return true
		default:
			return false
		}
	}
}

//MARK: - ViewControllerTransitionHelper
private class ViewControllerTransitionHelper : NSObject,  UIViewControllerAnimatedTransitioning {
	
	/**
		Default closure for handling prensentation transition animation with similar transition to default iOS cover vertical transition style.
		This will be overriden by the user of the owner class, SimpleTransitioningDelegate or InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionPresent: TransitionViewController = {(fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, isInteractive: Bool, isInteractiveTransitionCancelled: Bool, completion: () -> Void) in
		
		if !isInteractive {
			// Set initial frame only if the transition is not interactive
			let beginFrame = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(containerView.bounds))
			toViewController.view.frame = beginFrame
		}
		
		let endFrame: CGRect = containerView.bounds
		
		UIView.animateWithDuration(defaultTransitionAnimationDuration, animations: {
			toViewController.view.frame = endFrame
			}, completion: { (finished) in
				completion()
		})
	}
	/**
		Default closure for handling dismiss transition animation with similar transition to default iOS cover vertical transition style.
		This will be overriden by the user of the owner class, SimpleTransitioningDelegate or InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionDismiss: TransitionViewController = {(fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, isInteractive: Bool, isInteractiveTransitionCancelled: Bool, completion: () -> Void) in
		
		let endFrame = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(containerView.bounds))
		
		UIView.animateWithDuration(defaultTransitionAnimationDuration, animations: {
			fromViewController.view.frame = endFrame
			}, completion: { (finished) in
				completion()
		})
	}
	/**
		Default closure for handling presentation transition percentage change.
		This will be overriden by the user of the owner class, InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionPercentPresent: PercentTransitionViewController? = {(fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) in
		
		let endFrame = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(containerView.bounds) * (maximumInteractiveTransitionPercentage - percentage))
		toViewController.view.frame = endFrame
	}
	/**
		Default closure for handling dismissal transition percentage change.
		This will be overriden by the user of the owner class, InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionPercentDismiss: PercentTransitionViewController? = {(fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) in
		
		let endFrame = CGRectOffset(containerView.bounds, 0, CGRectGetHeight(containerView.bounds) * percentage)
		fromViewController.view.frame = endFrame
	}
	
	/**
		Current direction of the transition, default is no transition
	*/
	var transitionDirection: TransitionDirection = .None
	/**
		Transition context provided by either simple or interactive transitioning delegate
	*/
	var transitionContext: UIViewControllerContextTransitioning?
	
	/**
		Handles placing transitioning view controllers' views in transitionContext's containerView and performing the actual animation using transitionPresent, transitionDismiss, transitionPercentPresent and transitionPercentDismiss depending on the transitionState using the current transitionDirection.
	*/
	var transitionState: TransitionState = .None {
		didSet {
			
			guard !self.transitionState.isNone else {
				return
			}
			
			guard let transitionContext = self.transitionContext else {
				// Shouldn't be a case where transitionContext is nil
				return
			}
			
			let containerView = transitionContext.containerView()!
			
			// Making transitionState conditions more readable with these booleans
			let didTransitionStart = self.transitionState.didTransitionStart
			let isPercentDriven = self.transitionState.isPercentDriven
			let didTransitionEnd = self.transitionState.didTransitionEnd
			let isInteractiveTransitionCancelled = self.transitionState.isInteractiveTransitionCancelled
			let isInteractive = self.transitionState.isInteractive
			let percentage = self.transitionState.percentage
			
			let fromViewController = transitionContext.viewControllerForKey(UITransitionContextFromViewControllerKey)!
			let toViewController = transitionContext.viewControllerForKey(UITransitionContextToViewControllerKey)!
			
			// Place transitioning view controllers' views in containerView
			switch self.transitionDirection {
			case .Presenting:
				if didTransitionStart {
					containerView.addSubview(fromViewController.view)
					containerView.addSubview(toViewController.view)
				} else if didTransitionEnd && !isInteractive {
					containerView.addSubview(toViewController.view)
				}
			case .Dismissing:
				if didTransitionStart {
					
					// Setting presenting view controller's frame as containerView bounds. This helps with fixing misalignment if the containerView bounds changed after the initial transition, e.g. with in-call status bar.
					toViewController.view.frame = containerView.bounds
					
					if !isInteractive {
						containerView.insertSubview(toViewController.view, atIndex: 0)
					} else {
						containerView.insertSubview(toViewController.view, atIndex: 0)
						containerView.addSubview(fromViewController.view)
					}
				}
			default:
				break
			}
			
			// Presenting view controller's user interaction should be disabled during transition to prevent possible colliding interaction
			fromViewController.view.userInteractionEnabled = false
			
			// This closure is to be called at the end of provided transitionPresent and transitionDismiss callback closures
			let completion = {
				if transitionContext.transitionWasCancelled() {
					if isInteractive {
						transitionContext.cancelInteractiveTransition()
					}
					
					transitionContext.completeTransition(false)
					
					fromViewController.view.frame = containerView.frame
					UIApplication.sharedApplication().keyWindow?.addSubview(fromViewController.view)
				} else {
					if isInteractive {
						transitionContext.finishInteractiveTransition()
					}
					
					transitionContext.completeTransition(true)
					
					toViewController.view.frame = containerView.frame
					UIApplication.sharedApplication().keyWindow?.addSubview(toViewController.view)
				}
				
				fromViewController.view.userInteractionEnabled = true
				
				// Cleaning up
				self.transitionDirection = .None
				self.transitionContext = nil
				self.transitionState = .None
			}
			
			if (!isPercentDriven) {
				var animatePresenting = self.transitionDirection == .Presenting
				var reverseFromAndToViewControllers = false
				
				if (isInteractiveTransitionCancelled) {
					reverseFromAndToViewControllers = true
					
					switch self.transitionDirection {
					case .Presenting:
						animatePresenting = false
					case .Dismissing:
						animatePresenting = true
					default:
						break
					}
				}
				
				let reversedFromViewController = (reverseFromAndToViewControllers) ? toViewController : fromViewController
				let reversedToViewController = (reverseFromAndToViewControllers) ? fromViewController : toViewController
				
				if animatePresenting {
					self.transitionPresent(fromViewController: reversedFromViewController, toViewController: reversedToViewController, containerView: containerView, isInteractive: isInteractive, isInteractiveTransitionCancelled: isInteractiveTransitionCancelled, completion: completion)
				} else {
					self.transitionDismiss(fromViewController: reversedFromViewController, toViewController: reversedToViewController, containerView: containerView, isInteractive: isInteractive, isInteractiveTransitionCancelled: isInteractiveTransitionCancelled, completion: completion)
				}
			} else {
				switch self.transitionDirection {
				case .Presenting:
					self.transitionPercentPresent?(fromViewController: fromViewController, toViewController: toViewController, percentage: percentage, containerView: containerView)
				case .Dismissing:
					self.transitionPercentDismiss?(fromViewController: fromViewController, toViewController: toViewController, percentage: percentage, containerView: containerView)
				default:
					break
				}
				
				// Because there is no completion for percent driven callbacks, user interaction is enabled after each callback call.
				fromViewController.view.userInteractionEnabled = true
			}
		}
	}
	
	//MARK: UIViewControllerAnimatedTransitioning
	@objc private func transitionDuration(transitionContext: UIViewControllerContextTransitioning?) -> NSTimeInterval {
		return defaultTransitionAnimationDuration
	}
	
	/**
		This is used by SimpleTransitioningDelegate as in the protocol implementation. On the other hand, setting transitionContext and calling setTransitionState is manually handled by InteractiveTransitioningDelegate.
	*/
	@objc private func animateTransition(transitionContext: UIViewControllerContextTransitioning) {
		
		guard !transitionContext.isInteractive() else {
			return
		}
		
		self.transitionContext = transitionContext
		switch self.transitionDirection {
		case .Presenting:
			self.transitionState = .Finish(isInteractive: false)
		case .Dismissing:
			self.transitionState = .Start(isInteractive: false)
		default:
			break
		}
	}
	
}

//MARK: - SimpleTransitioningDelegate
/**
	SimpleTransitioningDelegate
	Use for simple view controller transitions that doesn't require user interaction driven transition by providing your animation blocks with its callback closure properties.
	- Implements UIViewControllerTransitioningDelegate
*/
public class SimpleTransitioningDelegate : NSObject, UIViewControllerTransitioningDelegate {
	
	public var transitionPresent: TransitionViewController {
		get {
			return self.transitionHelper.transitionPresent
		}
		set {
			self.transitionHelper.transitionPresent = newValue
		}
	}
	public var transitionDismiss: TransitionViewController {
		get {
			return self.transitionHelper.transitionDismiss
		}
		set {
			self.transitionHelper.transitionDismiss = newValue
		}
	}
	
	private let transitionHelper: ViewControllerTransitionHelper = ViewControllerTransitionHelper()
	
	//MARK: UIViewControllerTransitioningDelegate
	public func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		self.transitionHelper.transitionDirection = .Presenting
		return self.transitionHelper
	}
	
	public func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		self.transitionHelper.transitionDirection = .Dismissing
		return self.transitionHelper
	}
}

//MARK: - InteractiveTransitioningDelegate
/**
	InteractiveTransitioningDelegate
	Use for user interaction driven transitions by providing your animation blocks with its callback closure properties.
	- Subclasses UIPercentDrivenInteractiveTransition
	- Implements UIViewControllerTransitioningDelegate
*/
public class InteractiveTransitioningDelegate : UIPercentDrivenInteractiveTransition, UIViewControllerTransitioningDelegate {
	
	/**
		Whether the modal view controller is being presented or not
	*/
	public var isPresenting: Bool {
		return self.transitionHelper.transitionDirection == .Presenting
	}
	
	/**
		Whether the modal view controller is being dismissed or not
	*/
	public var isDismissing: Bool {
		return self.transitionHelper.transitionDirection == .Dismissing
	}
	
	/**
		Callback function for handling presentation transition
	*/
	public var transitionPresent: TransitionViewController {
		get {
			return self.transitionHelper.transitionPresent
		}
		set {
			self.transitionHelper.transitionPresent = newValue
		}
	}
	
	/**
		Callback function for handling dismissal transition
	*/
	public var transitionDismiss: TransitionViewController {
		get {
			return self.transitionHelper.transitionDismiss
		}
		set {
			self.transitionHelper.transitionDismiss = newValue
		}
	}
	
	/**
		Callback function for handling interactive presentation transition
	*/
	public var transitionPercentPresent: PercentTransitionViewController? {
		get {
			return self.transitionHelper.transitionPercentPresent
		}
		set {
			self.transitionHelper.transitionPercentPresent = newValue
		}
	}
	
	/**
		Callback function for handling interactive dismissal transition
	*/
	public var transitionPercentDismiss: PercentTransitionViewController? {
		get {
			return self.transitionHelper.transitionPercentDismiss
		}
		set {
			self.transitionHelper.transitionPercentDismiss = newValue
		}
	}
	
	/**
		Helper which implements UIViewControllerAnimatedTransitioning
		For internal use
	*/
	private let transitionHelper: ViewControllerTransitionHelper = ViewControllerTransitionHelper()
	
	/**
		Internal flag to keep track of interactive state before a transitionContext is created
	*/
	private var isInteractiveTransition: Bool = false
	
	/**
		Starts presenting the modal view controller in a percent driven way.
		Call this method to get provided transitionPercentPresent method called with current percentage while presenting. Percentage will be provided via calling updateInteractiveTransition(percentComplete) method.
	
		- parameter viewController: Modal view controller to present
		- parameter fromViewController: Parent view controller
	*/
	public func beginPresenting(viewController viewController: UIViewController, fromViewController: UIViewController) {
		
		// Prevent executing duplicate calls
		if (self.transitionHelper.transitionContext != nil && self.transitionHelper.transitionContext!.isInteractive()) {
			return
		}
		
		// Flag to mark that the modal view controller is going to be presented in a percent driven way
		self.isInteractiveTransition = true
		
		// Present the modal view controller in the regular way
		fromViewController.presentViewController(viewController, animated: true, completion: nil)
	}
	
	/**
		Starts dismissing the modal view controller in a percent driven way.
		Call this method to get provided transitionPercentDismiss method called with current percentage while presenting. Percentage will be provided via calling updateInteractiveTransition(percentComplete) method.
	
		- parameter viewController: Modal view controller to dismiss
	*/
	public func beginDismissing(viewController viewController: UIViewController) {
		
		// Prevent executing duplicate calls
		if (self.transitionHelper.transitionContext != nil && self.transitionHelper.transitionContext!.isInteractive()) {
			return
		}
		
		// Flag to mark that the modal view controller is going to be dismissed in a percent driven way
		self.isInteractiveTransition = true
		
		// Dismiss the modal view controller in the regular way
		viewController.dismissViewControllerAnimated(true, completion: nil)
	}
	
	/**
		Call this method to finalize after presenting or dismissing the view controller in a percent driven way.
	
		- parameter finished: true if the transtion is completed(e.g. interactively changed percentage exceeded the required threshold to present the view controller), false if the the transition is cancelled
	*/
	public func finalizeInteractiveTransition(isTransitionCompleted completed: Bool) {
		if completed {
			self.finishInteractiveTransition()
		} else {
			self.cancelInteractiveTransition()
		}
	}
	
	//MARK: UIViewControllerTransitioningDelegate
	public func animationControllerForPresentedController(presented: UIViewController, presentingController presenting: UIViewController, sourceController source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		
		if self.isInteractiveTransition {
			// If an interactive transition already started, return the transition helper
			return self.transitionHelper
		}
		
		if self.transitionHelper.transitionDirection != .Presenting {
			// Starting animated(non-percent driven) presentation
			self.transitionHelper.transitionDirection = .Presenting
			return self.transitionHelper
		}
		
		return nil
	}
	
	public func animationControllerForDismissedController(dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		
		if self.isInteractiveTransition {
			// If an interactive transition already started, return the transition helper
			return self.transitionHelper
		}
		
		if self.transitionHelper.transitionDirection != .Dismissing {
			// Starting animated(non-percent driven) dismissal
			self.transitionHelper.transitionDirection = .Dismissing
			return self.transitionHelper
		}
		
		return nil
	}
	
	public func interactionControllerForPresentation(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
		
		if self.transitionHelper.transitionDirection != .Presenting {
			// Mark the transition state while beginning an interactive presentation
			self.transitionHelper.transitionDirection = .Presenting
			return self
		}
		
		return nil
	}
	
	public func interactionControllerForDismissal(animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
		
		if self.transitionHelper.transitionDirection != .Dismissing {
			// Mark the transition state while beginning an interactive dismissal
			self.transitionHelper.transitionDirection = .Dismissing
			return self
		}
		
		return nil
	}
	
	//MARK: UIPercentDrivenInteractiveTransition
	/**
		There is no need to call UIPercentDrivenInteractiveTransition methods except for updateInteractiveTransition(percentComplete)
	*/
	public override func startInteractiveTransition(transitionContext: UIViewControllerContextTransitioning) {
		
		// Initialize the transitionContext of transitionHelper
		self.transitionHelper.transitionContext = transitionContext
		
		self.transitionHelper.transitionState = .Start(isInteractive: true)
	}
	
	/**
		Call this method in order to update percentage of presentation or dismissal
	*/
	public override func updateInteractiveTransition(percentComplete: CGFloat) {
		super.updateInteractiveTransition(percentComplete)
		
		self.transitionHelper.transitionState = .InteractivePercentage(isInteractive: true, percentage: percentComplete)
	}
	
	public override func finishInteractiveTransition() {
		// End interactive transition state
		// Because the transition has ended, isInteractiveTransition flag can be marked false
		self.isInteractiveTransition = false
		self.transitionHelper.transitionState = .Finish(isInteractive: true)
		
		super.finishInteractiveTransition()
	}
	
	public override func cancelInteractiveTransition() {
		// End interactive transition state
		// Because the transition has ended, isInteractiveTransition flag can be marked false
		self.isInteractiveTransition = false
		self.transitionHelper.transitionState = .Cancel(isInteractive: true)
		
		super.cancelInteractiveTransition()
	}
	
}
