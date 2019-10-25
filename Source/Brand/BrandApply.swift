/*

	Brand.swift
	BrandKit

	Created by Torsten Louland on 04/01/2018.

	MIT License

	Copyright (c) 2018 Torsten Louland

	Permission is hereby granted, free of charge, to any person obtaining a copy
	of this software and associated documentation files (the "Software"), to deal
	in the Software without restriction, including without limitation the rights
	to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
	copies of the Software, and to permit persons to whom the Software is
	furnished to do so, subject to the following conditions:

	The above copyright notice and this permission notice shall be included in all
	copies or substantial portions of the Software.

	THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
	IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
	FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
	AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
	LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
	OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
	SOFTWARE.
*/

import Foundation
import T0Utils

#if os(iOS)
import UIKit
#elseif os(macOS)
import AppKit
#endif



extension Brand
{
	// MARK: -
	public struct RelativeDimension : Codable
	{
		public enum Dimension : String, Codable { case width, height }
		public let dimension:			Dimension
		public let relation:			Unified.LayoutRelation
		public let relativeTo:			String
		public let multiplier:			CGFloat
		public let constant:			CGFloat
	}

	public enum ContentMode : String, Codable {
		case center, top, bottom, left, right, topLeft, topRight, bottomLeft, bottomRight
		// following pairs are synonyms, first is CALayer.contentsGravity, second is UIView.ContentMode
		case resize, scaleToFill
		case resizeAspect, scaleAspectFit
		case resizeAspectFill, scaleAspectFill
		// Custom special:
		case exactFit // ==> use resize/scaleToFill AND constrain container to resize preserving aspect
	}

	/// - `placementRules` gives one or more layout rules, separated by semicolons and expressed in
	/// visual format language. These can be supplied when there are strict placement rules, e.g.:
	/// associated with use of a brand image. The format rules will expect to reference the view
	/// by name "view" in the views dictionary passed to
	/// `NSLayoutConstraint.constraints(withVisualFormat:options:metrics:views:)`.
	/// - `auxiliaryViews` names any additional views that are needed by the placementRules. If
	/// supplied, add a transparent view for each, as siblings of the target view, and add by name to
	/// the views dictionary passed when creating the placement rules.
	/// - `metricNames` can be used to supply a list of names of metrics, separated by semicolons;
	/// a dictionary of their names and values obtained from the brandData are passed into
	/// `NSLayoutConstraint.constraints(withVisualFormat:options:metrics:views:)`.
	/// - `relativeDimensions` allows width or height to be expressed relative to other views (as
	/// the visual format language used in `placementRules` is unable to express this). The
	/// `relativeTo` field in each entry indexes into the same viewsByName dictionary needed by
	/// `placementRules`
	/// - `contentMode` allows the way the content in a view is placed to be specified; this is
	/// of interest for images (or (rare) views where the view's layer receives content of a
	/// different size tot he view). You can also specify it within an ImageEntry for simple cases
	/// that don't need extra placement rules, or you can specify it here, which is useful when a
	/// a view's image does not orignate from an image entry.
	public struct Placement : Codable
	{
	//	todo: non-optional (but possibly empty); unpacked placementRules string into array; add metricNames - a list of the metrics that will be used in the placement rules
		public let placementRules:		String?
		public let auxiliaryViews:		String?
		public let metricNames:			String?
		public let relativeDimensions:	[RelativeDimension]?
		public let contentMode:			ContentMode?
	}
}



// MARK: - Placement
extension Brand.Placement
{
	public func apply(to viewToPlace: Unified.View, using brand: Brand? = nil, surroundings: [String:Unified.View]? = nil, reducingPriorityBy: Int? = nil)
	{
		var views = surroundings ?? [String:Unified.View]()
		views["view"] = viewToPlace
		if let superview = viewToPlace.superview {
			views["super"] = superview
		}
		var metrics = [String:CGFloat]()
		if let names = self.metricNames, let brand = brand {
			for s in names.replacingOccurrences(of: " ", with: "").split(separator: ";") {
				if s.isEmpty { continue }
				let name = String(s)
				let metric = brand.metric(Brand.MetricKind(rawValue: name))
				if metric == Brand.kInvalidMetric { continue }
				metrics[name] = metric
			}
		}
		var constraints = [NSLayoutConstraint]()
		if let rules = self.placementRules {
			if let auxViews = self.auxiliaryViews, let superview = viewToPlace.superview {
				for name in auxViews.split(separator: ";") {
					if name.isEmpty { continue }
					let view = Unified.View(frame: .zero)
				#if os(iOS)
					view.backgroundColor = nil
					view.isOpaque = false
				#elseif os(macOS)
				#endif
					superview.addSubview(view)
					views[String(name)] = view
				}
			}
			for format in rules.split(separator: ";") {
				if format.isEmpty { continue }
				let more = NSLayoutConstraint.constraints(withVisualFormat: String(format), options: [], metrics: metrics, views: views)
				constraints.append(contentsOf: more)
			}
		}
		if let rds = self.relativeDimensions {
			for rd in rds {
				guard let relativeTo = views[rd.relativeTo] else { continue }
				let target = viewToPlace
				let attribute: Unified.LayoutAttribute = rd.dimension == .width ? .width : .height
				let constraint = NSLayoutConstraint(item: target, attribute: attribute, relatedBy: rd.relation, toItem: relativeTo, attribute: attribute, multiplier: rd.multiplier, constant: rd.constant)
				constraints.append(constraint)
			}
		}
		viewToPlace.removeBrandConstraints(forKey: "")
		if !constraints.isEmpty, let superview = viewToPlace.superview {
			if let rpb = reducingPriorityBy {
				constraints.forEach
					{ $0.priority = Unified.LayoutPriority($0.priority.rawValue - Float(rpb)) }
			}
			NSLayoutConstraint.activate(constraints)
			superview.addConstraints(constraints)
			viewToPlace.addBrandConstraints(constraints, forKey: "")
		}
		if let contentMode = self.contentMode {
			viewToPlace.contentMode = contentMode.viewContentMode
			if	contentMode.constrainContainerAspect,
				let image = (viewToPlace as? Unified.ImageView)?.image {
				Brand.Placement.constrain(view: viewToPlace, toAspect: image.size)
			}
		}
	}

	public static func constrain(view: Unified.View, toAspect aspect: CGSize, reducingPriorityBy: Int? = nil)
	{
		var aspectConstraint: NSLayoutConstraint? = nil
		for c in view.constraints {
			guard let item1 = c.firstItem, let item2 = c.secondItem else { continue }
			guard item1 === view && item2 === view && c.relation == .equal else { continue }
			if	(c.firstAttribute == .width && c.secondAttribute == .height)
			||	(c.firstAttribute == .height && c.secondAttribute == .width)
			{
				view.removeConstraint(c)
				let multiplier = c.firstAttribute == .width ? aspect.width / aspect.height
															: aspect.height / aspect.width
				aspectConstraint = NSLayoutConstraint(item: item1, attribute: c.firstAttribute, relatedBy: c.relation, toItem: item2, attribute: c.secondAttribute, multiplier: multiplier, constant: 0)
				aspectConstraint?.priority = c.priority
				break
			}
		}
		if	aspectConstraint == nil {
			aspectConstraint = NSLayoutConstraint(item: view, attribute: .width, relatedBy: .equal, toItem: view, attribute: .height, multiplier: aspect.width / aspect.height, constant: 0)
		}
		if let constraint = aspectConstraint {
			if let rpb = reducingPriorityBy {
				constraint.priority = Unified.LayoutPriority(constraint.priority.rawValue - Float(rpb))
			}
			constraint.isActive = true
			view.addConstraint(constraint)
		}
	}
}



// MARK: -
fileprivate var kBrandConstraintsKey = "brand_constraints"

extension Unified.View
{
	struct WeakLayoutConstraint {
		weak var value: NSLayoutConstraint? = nil
		init(_ value: NSLayoutConstraint?) {self.value = value}
	}
	typealias ConstraintArraysByKey = [String:[WeakLayoutConstraint]]

	public func addBrandConstraints(_ c: [NSLayoutConstraint], forKey key: String) {
		if c.isEmpty { return }
		let objGet = objc_getAssociatedObject(self, &kBrandConstraintsKey)
		var constraintArraysByKey = objGet as? ConstraintArraysByKey ?? ConstraintArraysByKey()
		var constraintArrayForKey = constraintArraysByKey[key] ?? [WeakLayoutConstraint]()
		constraintArrayForKey = c.reduce(into: constraintArrayForKey)
			{ (array, constraint) in
				array.append(WeakLayoutConstraint(constraint))
			}
		constraintArraysByKey[key] = constraintArrayForKey
		let objSet = constraintArraysByKey as NSDictionary
		objc_setAssociatedObject(self, &kBrandConstraintsKey, objSet, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
	}

	public func brandConstraints(forKey key: String) -> [NSLayoutConstraint] {
		var constraints = [NSLayoutConstraint]()
		let objGet = objc_getAssociatedObject(self, &kBrandConstraintsKey)
		if	let constraintArraysByKey = objGet as? ConstraintArraysByKey,
			let constraintArrayForKey = constraintArraysByKey[key]
		{
			// get the refs that are still alive out of the weak ref containers
			constraints = constraintArrayForKey.compactMap { $0.value }
		}
		return constraints
	}

	public func removeBrandConstraints(forKey key: String? = nil) {
		guard let objGet = objc_getAssociatedObject(self, &kBrandConstraintsKey)
		else { return }
		guard var constraintArraysByKey = objGet as? ConstraintArraysByKey
		else { return }
		var constraints = [NSLayoutConstraint]()
		var update = false
		if let key = key, let constraintArrayForKey = constraintArraysByKey[key] {
			constraints = constraintArrayForKey.compactMap { $0.value }
			constraintArraysByKey[key] = nil
			self.superview?.removeConstraints(constraints)
			update = true
		}
		if nil == key {
			for (_, constraintArrayForKey) in constraintArraysByKey {
				constraints = constraintArrayForKey.compactMap { $0.value }
				self.superview?.removeConstraints(constraints)
				update = true
			}
			constraintArraysByKey.removeAll()
		}
		if update {
			if !constraintArraysByKey.isEmpty {
				let objSet = constraintArraysByKey as NSDictionary
				objc_setAssociatedObject(self, &kBrandConstraintsKey, objSet, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			} else {
				objc_setAssociatedObject(self, &kBrandConstraintsKey, nil, .OBJC_ASSOCIATION_RETAIN_NONATOMIC)
			}
		}
	}
}



