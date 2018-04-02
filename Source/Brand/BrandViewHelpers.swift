/*
	BrandViewHelpers.swift
	BrandKit

	Created by Torsten Louland on 17/03/2018.

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


import UIKit
import T0Utils



public typealias UIViewBrandingParams = UIView.ViewBrandingParams
public typealias UIStackViewBrandingParams = UIStackView.StackViewBrandingParams
public typealias UICollectionViewBrandingParams = UICollectionView.CollectionViewBrandingParams
public typealias UICollectionViewCellBrandingParams = UICollectionViewCell.CellBrandingParams
public typealias UICollectionViewFlowLayoutBrandingParams = UICollectionViewFlowLayout.FlowLayoutBrandingParams



extension UIView
{
	public struct ViewBrandingParams {
		public var backgroundColor:	UIColor? = nil
		public var borderColor:		UIColor? = nil
		public var borderWidth:		CGFloat = 0
		public init(){}
		public init(_ accessor: BrandParameterAccessor) {
			backgroundColor = accessor.color(at: "backgroundColor")
			borderColor = accessor.color(at: "borderColor")
			borderWidth = accessor.float(at: "borderWidth") ?? 0
		}
		public var needApply: Bool { return backgroundColor != nil || needBorder }
		public var needBorder: Bool { return borderWidth != 0 && borderColor != nil && borderColor != .clear }
		public var needBackground: Bool { return backgroundColor != nil && backgroundColor != .clear }
		public func apply(to view: UIView) {
			guard needApply else { return }
			view.backgroundColor = backgroundColor
			view.isOpaque = 1 == backgroundColor?.cgColor.alpha
			if borderWidth != 0, let bgc = borderColor?.cgColor {
				view.layer.borderWidth = fabs(borderWidth)
				view.layer.borderColor = bgc
			}
		}
	}
}



// MARK: -
extension UICollectionViewCell
{
	public struct CellBrandingParams {
		public enum Background { case normal, selected }
		public var normal:			ViewBrandingParams? = nil
		public var selected:		ViewBrandingParams? = nil
		public init(){}
		public init(_ accessor: BrandParameterAccessor) {
			if nil != accessor.object(at: "normal") {
				normal = ViewBrandingParams(accessor.accessor(at: "normal"))
			}
			if nil != accessor.object(at: "selected") {
				selected = ViewBrandingParams(accessor.accessor(at: "selected"))
			}
		}

		public func apply(to bg: Background, of cell: UICollectionViewCell) {
			guard let p = bg == .selected ? selected : normal
			else { return }
			var view: UIView? = nil
			if p.needBorder || p.needBackground {
				if let v = (bg == .selected ? cell.selectedBackgroundView : cell.backgroundView) {
					view = v
				} else {
					view = UIView(frame: cell.bounds)
				}
			}
			switch bg {
				case .normal:	cell.backgroundView =			view
				case .selected:	cell.selectedBackgroundView =	view
			}
			if let view = view {
				p.apply(to: view)
			}
		}

		public func apply(to cell: UICollectionViewCell) {
			apply(to: .normal, of: cell)
			apply(to: .selected, of: cell)
		}
	}
}



// MARK: -
extension UICollectionViewFlowLayout
{
	public struct FlowLayoutBrandingParams {
		public var scrollDirection:	UICollectionViewScrollDirection = .vertical
		public var itemGap:			CGFloat = 0 // gap in fit direction
		public var lineGap:			CGFloat = 0 // gap in scroll direction
		public var header:			CGFloat? = nil // header dimension in scroll direction
		public var footer:			CGFloat? = nil // header dimension in scroll direction
		// itemSize and itemCount are used for FlowLayoutSizingRequest (-> request explicit or
		// fitting sizes) - see its description
		public var itemSize:		CGSize = .zero
		public var itemCount:		CGSize = .zero

		public init(_ dir: UICollectionViewScrollDirection, _ dim: CGFloat = 0) {
			scrollDirection = dir
			if dir == .vertical { itemSize.width = dim } else { itemSize.height = dim }
		}

		public init(_ accessor: BrandParameterAccessor) {
			scrollDirection = UICollectionViewScrollDirection(accessor.string(at: "scrollDirection") ?? "v") ?? .vertical
			lineGap = accessor.float(at: "lineGap") ?? 0
			itemGap = accessor.float(at: "itemGap") ?? 0
			header = accessor.float(at: "header")
			footer = accessor.float(at: "footer")
			itemSize = accessor.size(at: "itemSize") ?? .zero
			itemCount = accessor.size(at: "itemCount") ?? .zero
			BKLog.warningIf(itemSize.width != 0 && itemCount.width != 0, "FlowLayoutBrandingParams column count (itemCount.width) of \(itemCount.width) will be ignored in favour of explicit itemSize.width of \(itemSize.width)")
			BKLog.warningIf(itemSize.height != 0 && itemCount.height != 0, "FlowLayoutBrandingParams row count (itemCount.height) of \(itemCount.height) will be ignored in favour of explicit itemSize.height of \(itemSize.height)")
			BKLog.warningIf(
				scrollDirection == .vertical && itemSize.width == 0 && itemCount.width != round(itemCount.width),
				"FlowLayoutBrandingParams column count must be integral scrolling vertically - \(max(1,round(itemCount.width))) columns will be used instead of \(itemCount.width) (itemCount.width)")
			BKLog.warningIf(
				scrollDirection == .horizontal && itemSize.height == 0 && itemCount.height != round(itemCount.height),
				"FlowLayoutBrandingParams row count must be integral scrolling horizontally - \(max(1,round(itemCount.height))) rows will be used instead of \(itemCount.height) (itemCount.height)")
		}

		public func apply(to fl: UICollectionViewFlowLayout) {
			BKLog.warningIf(nil == fl.collectionView && (itemSize.width == 0 || itemSize.height == 0),
				"FlowLayoutBrandingParams cannot evaluate dynamic item sizes (= fit rows/cols to collection view area) until layout is installed in a collection view")

			fl.scrollDirection = scrollDirection
			fl.minimumLineSpacing = lineGap
			fl.minimumInteritemSpacing = itemGap

			var size = fl.itemSize
			if let header = header { switch scrollDirection {
				case .vertical:		fl.headerReferenceSize = CGSize(width: size.width, height: header)
				case .horizontal:	fl.headerReferenceSize = CGSize(width: header, height: size.height)
			} }
			if let footer = footer { switch scrollDirection {
				case .vertical:		fl.headerReferenceSize = CGSize(width: size.width, height: footer)
				case .horizontal:	fl.headerReferenceSize = CGSize(width: footer, height: size.height)
			} }

			let sizingRequest = FlowLayoutSizingRequest(sizes: itemSize, counts: itemCount)
			size = fl.dynamicItemSize(for: sizingRequest)
			fl.itemSize = size

			if let header = header { switch scrollDirection {
				case .vertical:		fl.headerReferenceSize = CGSize(width: size.width, height: header)
				case .horizontal:	fl.headerReferenceSize = CGSize(width: header, height: size.height)
			} }
			if let footer = footer { switch scrollDirection {
				case .vertical:		fl.headerReferenceSize = CGSize(width: size.width, height: footer)
				case .horizontal:	fl.headerReferenceSize = CGSize(width: footer, height: size.height)
			} }
		}
	}
}



// MARK: -
extension UICollectionView
{
	public struct CollectionViewBrandingParams {
		public var view:			UIView.ViewBrandingParams? = nil
		public var contentInset:	UIEdgeInsets = .zero
		public var flowLayout:		UICollectionViewFlowLayoutBrandingParams? = nil

		public init(view v: UIView.ViewBrandingParams? = nil, contentInset c: UIEdgeInsets = .zero, flowLayout f: UICollectionViewFlowLayoutBrandingParams? = nil) { view = v ; contentInset = c ; flowLayout = f }
		public init(_ accessor: BrandParameterAccessor) {
			let bp = ViewBrandingParams(accessor.accessor(at: "view"))
			view = bp.needApply ? bp : nil
			contentInset = accessor.insets(at: "contentInset") ?? .zero
			flowLayout = UICollectionViewFlowLayoutBrandingParams(accessor.accessor(at: "flowLayout"))
		}

		public func apply(to cv: UICollectionView, constraints: (w: NSLayoutConstraint, h: NSLayoutConstraint)? = nil) {
			view?.apply(to: cv)
			cv.contentInset = contentInset

			if	let fl = cv.collectionViewLayout as? UICollectionViewFlowLayout {
				flowLayout?.apply(to: fl)

				if let (cw, ch) = constraints {
					cw.isActive = fl.scrollDirection == .vertical
					ch.isActive = fl.scrollDirection == .horizontal
					let size = fl.minSize(forCols: 1, rows: 1)
					if fl.scrollDirection == .vertical {
						cw.constant = size.width
					} else {
						ch.constant = size.height
					}
				}
			}
		}
	}
}




// MARK: -
extension UIStackView
{
	public struct StackViewBrandingParams {
		var axis:			UILayoutConstraintAxis? = nil
		var alignment:		UIStackViewAlignment? = nil
		var distribution:	UIStackViewDistribution? = nil
		var clustering:		T0StackViewClustering = .none
		var margins:		UIEdgeInsets? = nil
		var spacing:		CGFloat? = nil
		public init(){}
		public init(_ accessor: BrandParameterAccessor) {
			axis = UILayoutConstraintAxis(accessor.string(at: "axis") ?? "")
			alignment = UIStackViewAlignment(accessor.string(at: "alignment") ?? "")
			distribution = UIStackViewDistribution(accessor.string(at: "distribution") ?? "")
			clustering = T0StackViewClustering(accessor.string(at: "clustering") ?? "") ?? .none
			margins = accessor.insets(at: "margins")
			spacing = accessor.float(at: "spacing")
		}
		public func apply(to sv: UIStackView) {
			if let axis = axis {
				sv.axis = axis
			}
			if let alignment = alignment {
				sv.alignment = alignment
			}
			if let distribution = distribution {
				sv.distribution = distribution
			}
			if let spacing = spacing {
				sv.spacing = spacing
			}
			if let margins = margins {
				sv.layoutMargins = margins
				sv.isLayoutMarginsRelativeArrangement = true
			}
			if let sv = sv as? T0StackView {
				sv.clustering = clustering
			}
		}
	}
}




