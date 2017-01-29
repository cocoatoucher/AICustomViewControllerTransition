//
//  AICustomViewControllerTransition.swift
//  AICustomViewControllerTransition
//
//  Created by cocoatoucher on 09/07/16.
//  Copyright © 2016 cocoatoucher. All rights reserved.
//

import UIKit

/**
	Transition type
	Whether the transition is Simple or Interactive, and additional information if interactive
*/
public enum TransitionType {
	/** 
		Non-interactive transition
	*/
	case simple
	/**
		Interactive transition
		- parameter isCancelled: true if transition is cancelled, false if transition is finished
		- parameter lastPercentage: last percentage value of the transition when it is cancelled or finished
	*/
	case interactive(isCancelled: Bool, lastPercentage: CGFloat)
	
	/**
		Handy var for interactive transtion cancelled status
		true or false if the transition is interactive
		nil if the transition is simple
	*/
	public var isInteractiveTransitionCancelled: Bool? {
		if case let .interactive(isCancelled, _) = self {
			return isCancelled
		}
		return nil
	}
	
	/**
		Handy var for last percentage of the interactive transition
		nil if the transition is simple
		non-nil if the transition is interactive
	*/
	public var lastPercentage: CGFloat? {
		if case let .interactive(_, lastPercentage) = self {
			return lastPercentage
		}
		return nil
	}
	
}

/**
	Transition handling closure

	- parameter fromViewController: Currently visible view controller
	- parameter toViewController: View controller to be displayed after the transition
	- parameter containerView: Transition view which will contain both fromViewController and toViewController's views. Place any temporary animated views on this view. During the animation, fromViewController and toViewController's views are subviews of containerView.
	- parameter transitionType: Whether the transition is Simple or Interactive, and additional information if interactive
	- parameter completion: This closure should be called at the end of your transition animation to finalize the transition
*/
public typealias TransitionViewController = ((_ fromViewController: UIViewController, _ toViewController: UIViewController, _ containerView: UIView, _ transitionType: TransitionType, _ completion: @escaping () -> Void) -> Void)

/**
	Interactive transition percentage handling closure

	- parameter fromViewController: Currently visible view controller
	- parameter toViewController: View controller to display
	- parameter percentage: Percentage of the transition phase. This will reflect the percentage value provided via updateInteractiveTransition(_:) of InteractiveTransitioningDelegate class
	- parameter containerView: Transition view which will contain both fromViewController and toViewController's views. Place any temporary animated views on this view
*/
public typealias PercentTransitionViewController = ((_ fromViewController: UIViewController, _ toViewController: UIViewController, _ percentage: CGFloat, _ containerView: UIView) -> Void)

/**
	Animation duration used within default transition animation closure values
*/
public let defaultTransitionAnimationDuration: TimeInterval = 0.3
/**
	Maximum percentage value used for percent driven interactive transition
*/
public let maximumInteractiveTransitionPercentage: CGFloat = 1.0
/**
	Minimum percentage value used for percent driven interactive transition
*/
public let minimumTransitionPercentage: CGFloat = 0.0

/**
	Transition directions
*/
private enum TransitionDirection {
	/**
		No transition
	*/
	case none
	/**
		Transitioning delegate is presenting a view controller
	*/
	case presenting
	/**
		Transitioning delegate is dismissing a view controller
	*/
	case dismissing
}

//MARK: - TransitionState
/**
	Transition states
*/
private enum TransitionState {
	/**
		No transition state
	*/
	case none
	/**
		Interactive transition has started either presenting or dismissing which can either be interactive or simple
		- parameter transitionType: Whether the transition is Simple or Interactive, and additional information if interactive
	*/
	case start(transitionType: TransitionType)
	/**
		State of an interactive transition, either presentation or dismissal, is changing percentage
		- parameter currentPercentage: Current percentage of interactive transition phase
	*/
	case interactivePercentage(currentPercentage: CGFloat)
	/**
		Interactive transition has completed either presenting or dismissing which can either be interactive or simple
		- parameter transitionType: Whether the transition is Simple or Interactive, and additional information if interactive
	*/
	case finish(transitionType: TransitionType)
	/**
		Interactive transition has cancelled either presenting or dismissing a view controller in an interactive way
		- parameter lastPercentage: Last percentage value of transition phase when the interactive transition is cancelled
	*/
	case cancelInteractive(lastPercentage: CGFloat)
	
	/**
		Handy var to get whether the transition state is none
	*/
	var isNone: Bool {
		if case .none = self {
			return true
		}
		return false
	}
	
	/**
		Handy var to get whether the transition type is interactive
	*/
	var isInteractive: Bool {
		switch self {
		case .start(let transitionType):
			if case .interactive = transitionType {
				return true
			}
			return false
		case .interactivePercentage:
			return true
		case .finish(let transitionType):
			if case .interactive = transitionType {
				return true
			}
			return false
		case .cancelInteractive(_):
			return true
		default:
			return false
		}
	}
	
	/**
		Handy var to get the percentage value of the transition state
		nil if the transition is Simple
	*/
	var percentage: CGFloat? {
		switch self {
		case .start(let transitionType):
			switch transitionType {
			case .interactive(_, let lastPercentage):
				return lastPercentage
			default:
				return nil
			}
		case .interactivePercentage(let currentPercentage):
			return currentPercentage
		case .finish(let transitionType):
			switch transitionType {
			case .interactive(_, let lastPercentage):
				return lastPercentage
			default:
				return nil
			}
		case .cancelInteractive(let lastPercentage):
			return lastPercentage
		default:
			return nil
		}
	}
	
	/**
		A transition state is considered percent driven in two cases
		1. Transition has started interactively, with percentage 0
		2. Transition is progressing with changing percentage in interactive state
	*/
	var isPercentDriven: Bool {
		switch self {
		case .start(let transitionType):
			if case .interactive = transitionType {
				return true
			}
			return false
		case .interactivePercentage:
			return true
		default:
			return false
		}
	}
	
	/**
		Handy var to get whether the transition has started
	*/
	var didTransitionStart: Bool {
		if case .start = self {
			return true
		}
		return false
	}
	
	/**
		Handy var to get whether the transition has ended
	*/
	var didTransitionEnd: Bool {
		switch self {
		case .finish, .cancelInteractive:
			return true
		default:
			return false
		}
	}
	
	/**
		Handy var to get whether the transition has cancelled
	*/
	var isInteractiveTransitionCancelled: Bool {
		if case .cancelInteractive = self {
			return true
		}
		return false
	}
}

//MARK: - ViewControllerTransitionHelper
/**
	Helper class which implements UIViewControllerAnimatedTransitioning
*/
private class ViewControllerTransitionHelper : NSObject,  UIViewControllerAnimatedTransitioning {
	
	/**
		Default closure for handling prensentation transition animation with similar transition to iOS cover vertical transition style.
		This will be overriden by the user of the owner class, SimpleTransitioningDelegate or InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionPresent: TransitionViewController = {(fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: @escaping () -> Void) in
		
		if case .simple = transitionType {
			// Set initial frame only if the transition is not interactive
			let beginFrame = containerView.bounds.offsetBy(dx: 0, dy: containerView.bounds.height)
			toViewController.view.frame = beginFrame
		}
		
		let endFrame: CGRect = containerView.bounds
		
		UIView.animate(withDuration: defaultTransitionAnimationDuration, delay: 0.0, options: .curveEaseInOut, animations: {
			toViewController.view.frame = endFrame
			}, completion: { (finished) in
				completion()
		})
	}
	/**
		Default closure for handling dismiss transition animation with similar transition to iOS cover vertical transition style.
		This will be overriden by the user of the owner class, SimpleTransitioningDelegate or InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionDismiss: TransitionViewController = {(fromViewController: UIViewController, toViewController: UIViewController, containerView: UIView, transitionType: TransitionType, completion: @escaping () -> Void) in
		
		let endFrame = containerView.bounds.offsetBy(dx: 0, dy: containerView.bounds.height)
		
		UIView.animate(withDuration: defaultTransitionAnimationDuration, delay: 0.0, options: .curveEaseInOut, animations: {
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
		
		let endFrame = containerView.bounds.offsetBy(dx: 0, dy: containerView.bounds.height * (maximumInteractiveTransitionPercentage - percentage))
		toViewController.view.frame = endFrame
	}
	/**
		Default closure for handling dismissal transition percentage change.
		This will be overriden by the user of the owner class, InteractiveTransitioningDelegate for custom animation.
	*/
	var transitionPercentDismiss: PercentTransitionViewController? = {(fromViewController: UIViewController, toViewController: UIViewController, percentage: CGFloat, containerView: UIView) in
		
		let endFrame = containerView.bounds.offsetBy(dx: 0, dy: containerView.bounds.height * percentage)
		fromViewController.view.frame = endFrame
	}
	
	/**
		Current direction of the transition, default is no transition
	*/
	var transitionDirection: TransitionDirection = .none
	/**
		Transition context provided by either simple or interactive transitioning delegate
	*/
	var transitionContext: UIViewControllerContextTransitioning?
	
	/**
		Handles placing transitioning view controllers' views in transitionContext's containerView and performing the actual animation using transitionPresent, transitionDismiss, transitionPercentPresent and transitionPercentDismiss depending on the transitionState using the current transitionDirection.
	*/
	var transitionState: TransitionState = .none {
		didSet {
			
			guard !self.transitionState.isNone else {
				return
			}
			
			guard let transitionContext = self.transitionContext else {
				// Shouldn't be a case where transitionContext is nil
				return
			}
			
			let containerView = transitionContext.containerView
			
			// Making transitionState conditions more readable with these booleans
			let didTransitionStart = self.transitionState.didTransitionStart
			let isPercentDriven = self.transitionState.isPercentDriven
			let didTransitionEnd = self.transitionState.didTransitionEnd
			let isInteractiveTransitionCancelled = self.transitionState.isInteractiveTransitionCancelled
			let isInteractive = self.transitionState.isInteractive
			let percentage = self.transitionState.percentage
			
			let fromViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.from)!
			let toViewController = transitionContext.viewController(forKey: UITransitionContextViewControllerKey.to)!
			
			// Place transitioning view controllers' views in containerView
			switch self.transitionDirection {
			case .presenting:
				if didTransitionStart {
					fromViewController.view.frame = containerView.convert(fromViewController.view.frame, from: fromViewController.view.superview!)
					containerView.addSubview(fromViewController.view)
					containerView.addSubview(toViewController.view)
				} else if didTransitionEnd && !isInteractive {
					containerView.addSubview(toViewController.view)
				}
			case .dismissing:
				if didTransitionStart {
					
					// Setting presenting view controller's frame as containerView bounds. This helps with fixing misalignment if the containerView bounds changed after the initial transition, e.g. with in-call status bar.
					toViewController.view.frame = containerView.bounds
					
					if !isInteractive {
						containerView.insertSubview(toViewController.view, at: 0)
					} else {
						containerView.insertSubview(toViewController.view, at: 0)
						containerView.addSubview(fromViewController.view)
					}
				}
			default:
				break
			}
			
			// Presenting view controller's user interaction should be disabled during transition to prevent possible colliding interaction
			fromViewController.view.isUserInteractionEnabled = false
			
			// This closure is to be called at the end of provided transitionPresent and transitionDismiss callback closures
			let completion = {
				if transitionContext.transitionWasCancelled {
					if isInteractive {
						transitionContext.cancelInteractiveTransition()
					}
					
					transitionContext.completeTransition(false)
					
					// Fix for iOS leak, where UITransitionViews remain on the screen
					// It's necessary to remove each view to the window
					let window = UIApplication.shared.keyWindow!
					if (isInteractive) {
						toViewController.view.frame = window.convert(toViewController.view.frame, from: toViewController.view.superview ?? window)
						window.addSubview(toViewController.view)
					}
					fromViewController.view.frame = window.convert(fromViewController.view.frame, from: fromViewController.view.superview ?? containerView)
					window.addSubview(fromViewController.view)
				} else {
					if isInteractive {
						transitionContext.finishInteractiveTransition()
					}
					
					transitionContext.completeTransition(true)
					
					// Fix for iOS leak, where UITransitionViews remain on the screen
					// It's necessary to remove each view to the window
					let window = UIApplication.shared.keyWindow!
					if (isInteractive) {
						fromViewController.view.frame = window.convert(fromViewController.view.frame, from: fromViewController.view.superview ?? containerView)
						window.addSubview(fromViewController.view)
					}
					toViewController.view.frame = window.convert(toViewController.view.frame, from: toViewController.view.superview ?? window)
					window.addSubview(toViewController.view)
				}
				
				fromViewController.view.isUserInteractionEnabled = true
				
				// Cleaning up
				self.transitionDirection = .none
				self.transitionContext = nil
				self.transitionState = .none
			}
			
			if (!isPercentDriven) {
				var animatePresenting = self.transitionDirection == .presenting
				var reverseFromAndToViewControllers = false
				
				if (isInteractiveTransitionCancelled) {
					reverseFromAndToViewControllers = true
					
					switch self.transitionDirection {
					case .presenting:
						animatePresenting = false
					case .dismissing:
						animatePresenting = true
					default:
						break
					}
				}
				
				let reversedFromViewController = (reverseFromAndToViewControllers) ? toViewController : fromViewController
				let reversedToViewController = (reverseFromAndToViewControllers) ? fromViewController : toViewController
				
				let transitionType: TransitionType = (isInteractive) ? .interactive(isCancelled: isInteractiveTransitionCancelled, lastPercentage: percentage!) : .simple
				
				if animatePresenting {
					self.transitionPresent(reversedFromViewController, reversedToViewController, containerView, transitionType, completion)
				} else {
					self.transitionDismiss(reversedFromViewController, reversedToViewController, containerView, transitionType, completion)
				}
			} else {
				switch self.transitionDirection {
				case .presenting:
					self.transitionPercentPresent?(fromViewController, toViewController, percentage!, containerView)
				case .dismissing:
					self.transitionPercentDismiss?(fromViewController, toViewController, percentage!, containerView)
				default:
					break
				}
				
				// Because there is no completion for percent driven callbacks, user interaction is enabled after each callback execution
				fromViewController.view.isUserInteractionEnabled = true
			}
		}
	}
	
	//MARK: UIViewControllerAnimatedTransitioning
	/**
		This is ignored, since the actual transition duration is specified in transition callback closures provided by transitioningDelegate classes
	*/
	@objc fileprivate func transitionDuration(using transitionContext: UIViewControllerContextTransitioning?) -> TimeInterval {
		return 0.0
	}
	
	/**
		This is used by SimpleTransitioningDelegate as in the protocol implementation. On the other hand, setting transitionContext and calling setTransitionState is manually handled by InteractiveTransitioningDelegate.
	*/
	@objc fileprivate func animateTransition(using transitionContext: UIViewControllerContextTransitioning) {
		
		guard !transitionContext.isInteractive else {
			return
		}
		
		self.transitionContext = transitionContext
		switch self.transitionDirection {
		case .presenting:
			self.transitionState = .finish(transitionType: .simple)
		case .dismissing:
			self.transitionState = .start(transitionType: .simple)
		default:
			break
		}
	}
	
}

//MARK: - SimpleTransitioningDelegate
/**
	SimpleTransitioningDelegate
	Use for simple view controller transitions that doesn't require user interaction driven transition by providing your animation blocks with its callback closure properties.
	Implements UIViewControllerTransitioningDelegate
*/
open class SimpleTransitioningDelegate : NSObject, UIViewControllerTransitioningDelegate {
	
	/**
		Whether the modal view controller is being presented or not
	*/
	open var isPresenting: Bool {
		return self.transitionHelper.transitionDirection == .presenting
	}
	
	/**
		Whether the modal view controller is being dismissed or not
	*/
	open var isDismissing: Bool {
		return self.transitionHelper.transitionDirection == .dismissing
	}
	
	/**
		Callback closure for handling prensentation transition animation. Default value is similar transition to iOS cover vertical transition style.
	*/
	open var transitionPresent: TransitionViewController {
		get {
			return self.transitionHelper.transitionPresent
		}
		set {
			self.transitionHelper.transitionPresent = newValue
		}
	}
	/**
		Callback closure for handling dismiss transition animation. Default value is similar transition to iOS cover vertical transition style.
	*/
	open var transitionDismiss: TransitionViewController {
		get {
			return self.transitionHelper.transitionDismiss
		}
		set {
			self.transitionHelper.transitionDismiss = newValue
		}
	}
	
	/**
		UIViewControllerAnimatedTransitioning helper
	*/
	fileprivate let transitionHelper: ViewControllerTransitionHelper = ViewControllerTransitionHelper()
	
	//MARK: UIViewControllerTransitioningDelegate
	/**
		This method shouldn't be called
	*/
	open func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		self.transitionHelper.transitionDirection = .presenting
		return self.transitionHelper
	}
	/**
		This method shouldn't be called
	*/
	open func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		self.transitionHelper.transitionDirection = .dismissing
		return self.transitionHelper
	}
}

//MARK: - InteractiveTransitioningDelegate
/**
	InteractiveTransitioningDelegate
	Use for user interaction driven transitions by providing your animation blocks with its callback closure properties.
	Subclasses UIPercentDrivenInteractiveTransition
	Implements UIViewControllerTransitioningDelegate
*/
open class InteractiveTransitioningDelegate : UIPercentDrivenInteractiveTransition, UIViewControllerTransitioningDelegate {
	
	/**
		Whether the modal view controller is being presented or not
	*/
	open var isPresenting: Bool {
		return self.transitionHelper.transitionDirection == .presenting
	}
	
	/**
		Whether the modal view controller is being dismissed or not
	*/
	open var isDismissing: Bool {
		return self.transitionHelper.transitionDirection == .dismissing
	}
	
	/**
		Callback closure for handling prensentation transition animation. Default value is similar transition to iOS cover vertical transition style.
	*/
	open var transitionPresent: TransitionViewController {
		get {
			return self.transitionHelper.transitionPresent
		}
		set {
			self.transitionHelper.transitionPresent = newValue
		}
	}
	
	/**
		Callback closure for handling dismiss transition animation. Default value is similar transition to iOS cover vertical transition style.
	*/
	open var transitionDismiss: TransitionViewController {
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
	open var transitionPercentPresent: PercentTransitionViewController? {
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
	open var transitionPercentDismiss: PercentTransitionViewController? {
		get {
			return self.transitionHelper.transitionPercentDismiss
		}
		set {
			self.transitionHelper.transitionPercentDismiss = newValue
		}
	}
	
	/**
		UIViewControllerAnimatedTransitioning helper
	*/
	fileprivate let transitionHelper: ViewControllerTransitionHelper = ViewControllerTransitionHelper()
	
	/**
		Internal flag to keep track of interactive state before a transitionContext is created
	*/
	fileprivate var isInteractiveTransition: Bool = false
	
	/**
		Starts presenting the modal view controller in a percent driven way.
		Call this method to get provided transitionPercentPresent method called with current percentage while presenting. Percentage will be provided via calling updateInteractiveTransition(percentComplete) method.
	
		- parameter viewController: Modal view controller to present
		- parameter fromViewController: Parent view controller
	*/
	open func beginPresenting(viewController: UIViewController, fromViewController: UIViewController) {
		
		// Prevent executing duplicate calls
		if (self.transitionHelper.transitionContext != nil && self.transitionHelper.transitionContext!.isInteractive) {
			return
		}
		
		// Flag to mark that the modal view controller is going to be presented in a percent driven way
		self.isInteractiveTransition = true
		
		// Present the modal view controller in the regular way
		fromViewController.present(viewController, animated: true, completion: nil)
	}
	
	/**
		Starts dismissing the modal view controller in a percent driven way.
		Call this method to get provided transitionPercentDismiss method called with current percentage while presenting. Percentage will be provided via calling updateInteractiveTransition(percentComplete) method.
	
		- parameter viewController: Modal view controller to dismiss
	*/
	open func beginDismissing(viewController: UIViewController) {
		
		// Prevent executing duplicate calls
		if (self.transitionHelper.transitionContext != nil && self.transitionHelper.transitionContext!.isInteractive) {
			return
		}
		
		// Flag to mark that the modal view controller is going to be dismissed in a percent driven way
		self.isInteractiveTransition = true
		
		// Dismiss the modal view controller in the regular way
		viewController.dismiss(animated: true, completion: nil)
	}
	
	/**
		Call this method to finalize after presenting or dismissing the view controller in a percent driven way.
	
		- parameter finished: true if the transtion is completed(e.g. interactively changed percentage exceeded the required threshold to present the view controller), false if the the transition is cancelled
	*/
	open func finalizeInteractiveTransition(isTransitionCompleted completed: Bool) {
		if completed {
			self.finish()
		} else {
			self.cancel()
		}
	}
	
	//MARK: UIViewControllerTransitioningDelegate
	/**
		This method shouldn't be called
	*/
	open func animationController(forPresented presented: UIViewController, presenting: UIViewController, source: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		
		if self.isInteractiveTransition {
			// If an interactive transition already started, return the transition helper
			return self.transitionHelper
		}
		
		if self.transitionHelper.transitionDirection != .presenting {
			// Starting animated(non-percent driven) presentation
			self.transitionHelper.transitionDirection = .presenting
			return self.transitionHelper
		}
		
		return nil
	}
	
	/**
		This method shouldn't be called
	*/
	open func animationController(forDismissed dismissed: UIViewController) -> UIViewControllerAnimatedTransitioning? {
		
		if self.isInteractiveTransition {
			// If an interactive transition already started, return the transition helper
			return self.transitionHelper
		}
		
		if self.transitionHelper.transitionDirection != .dismissing {
			// Starting animated(non-percent driven) dismissal
			self.transitionHelper.transitionDirection = .dismissing
			return self.transitionHelper
		}
		
		return nil
	}
	
	/**
		This method shouldn't be called
	*/
	open func interactionControllerForPresentation(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
		
		if self.transitionHelper.transitionDirection != .presenting {
			// Mark the transition state while beginning an interactive presentation
			self.transitionHelper.transitionDirection = .presenting
			return self
		}
		
		return nil
	}
	
	/**
		This method shouldn't be called
	*/
	open func interactionControllerForDismissal(using animator: UIViewControllerAnimatedTransitioning) -> UIViewControllerInteractiveTransitioning? {
		
		if self.transitionHelper.transitionDirection != .dismissing {
			// Mark the transition state while beginning an interactive dismissal
			self.transitionHelper.transitionDirection = .dismissing
			return self
		}
		
		return nil
	}
	
	//MARK: UIPercentDrivenInteractiveTransition
	/**
		This method shouldn't be called
	*/
	open override func startInteractiveTransition(_ transitionContext: UIViewControllerContextTransitioning) {
		
		// Initialize the transitionContext of transitionHelper
		self.transitionHelper.transitionContext = transitionContext
		
		self.transitionHelper.transitionState = .start(transitionType: .interactive(isCancelled: false, lastPercentage: 0))
	}
	
	/**
		Call this method in order to update percentage of presentation or dismissal
	*/
	open override func update(_ percentComplete: CGFloat) {
		super.update(percentComplete)
		
		self.transitionHelper.transitionState = .interactivePercentage(currentPercentage: percentComplete)
	}
	
	/**
		This method shouldn't be called
	*/
	open override func finish() {
		// End interactive transition state
		// Because the transition has ended, isInteractiveTransition flag can be marked false
		super.finish()
		self.isInteractiveTransition = false
		self.transitionHelper.transitionState = .finish(transitionType: .interactive(isCancelled: false, lastPercentage: self.percentComplete))
	}
	
	/**
		This method shouldn't be called
	*/
	open override func cancel() {
		// End interactive transition state
		// Because the transition has ended, isInteractiveTransition flag can be marked false
		super.cancel()
		self.isInteractiveTransition = false
		self.transitionHelper.transitionState = .cancelInteractive(lastPercentage: self.percentComplete)
	}
	
}
