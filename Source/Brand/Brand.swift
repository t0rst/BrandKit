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



class BKLog : T0Logging {}
public class Unified : T0Unified {}



#if DEBUG
public let kDefaultCoordinatedLoading = true
#else
public let kDefaultCoordinatedLoading = false
#endif



public enum BrandAssetKind {
	case color
	case metric
	case font			// type family and face at particular size for purpose
	case textAttributes	// attributes for text with a particular purpose (font, track, colour)
	case placement		// rules for placing a view (image, etc) for a particular purpose
	case image
	case buttonStyle	// stroke, fill, insets and textStyle per state for button with purpose
}



public protocol BrandAssetID : RawRepresentable, Hashable where RawValue == String {
	static var assetKind:		BrandAssetKind { get }
}

extension BrandAssetID {
	public var hashValue:				Int { return rawValue.hashValue }
}



// MARK: -
/// Supply assets (images, colours, metrics) for use aligning app appearance to project brand.
///
/// A Brand instance is attached to the configuration of a project. It knows what assets are
/// available, how and where to retrieve them, and it knows how to supply information and instances
/// to the rest of the app.
///
open class Brand : NSObject
{
	public static var makeDefaultBrandOnce: ()->Brand = { return Brand(storage: Bundle.main.bundleURL) }
	public static var `default`: Brand = { return makeDefaultBrandOnce() }()

	public static let fileName:		String = "appearance.json"
	let storage:				URL
	var data:					BrandData? = nil
	@objc dynamic private(set) public var sequence: Int
	var coordinatingLoading:	Bool = false {
		didSet {
			if coordinatingLoading == oldValue { return }
			if coordinatingLoading {
				NSFileCoordinator.addFilePresenter(self)
			#if DEBUG
				print(self.printEditingPrompt())
			#endif
			} else {
				NSFileCoordinator.removeFilePresenter(self)
			}
		}
	}

	public init(storage: URL)
	{
		self.storage = storage
		self.sequence = 0
	}

	deinit {
		coordinatingLoading = false
	}

	open var isLoaded: Bool { return data != nil }

	open func load(coordinate: Bool = kDefaultCoordinatedLoading) {
		if isLoaded && coordinate == coordinatingLoading { return }
		coordinatingLoading = coordinate
		reload()
	}

	open func reload()
	{
		var json = Data()
		if coordinatingLoading {
			var error: NSError? = nil
			let fc = NSFileCoordinator(filePresenter: self)
			fc.coordinate(readingItemAt: self.fileURL, options: [], error: &error)
				{ (url: URL) in
					do {
						json = try Data(contentsOf: url)
					} catch {
						BKLog.error("Reading brand data at \"\(storage)/\(Brand.fileName)\" prevented by error: \(error)")
					}
				}
			if let error = error {
				BKLog.error("Reading brand data at \"\(storage)/\(Brand.fileName)\" prevented by error: \(error)")
				return
			}
		} else {
			if let data = try? Data(contentsOf: self.fileURL) {
				json = data
			}
		}
		self.reload(from: json)
	}

	private func reload(from json: Data)
	{
		// In debug, we record all log messages during the loading and application of the brand
		// into a file next to the brand folder. This is to shorten the iterations of adjusting
		// the settings within the brand.
	#if DEBUG
		var writer: ((String)->Void)? = nil
		var done = false
		do {
			let logURL = storage.appendingPathComponent("appearance.log")
			let fc = NSFileCoordinator()
			var e: NSError? = nil
			fc.coordinate(writingItemAt: logURL, options: [.forMerging], error: &e)
				{ (_) in
					do { try "".write(to: logURL, atomically: true, encoding: .utf8) }
					catch { BKLog.error("Could not clear appearance log because\n\(error)") }
				}
			let logFH = try FileHandle(forWritingTo: logURL)
			let serialQ = DispatchQueue.Attributes(rawValue: 0) // i.e. omit .concurrent
			let logQ = DispatchQueue.init(label: "brandlogger", qos: .userInitiated, attributes: serialQ)
			writer = { (s: String)->Void in
				guard !done, let data = s.appending("\n").data(using: .utf8)
				else { return }
				logQ.async
					{
						var e: NSError? = nil
						fc.coordinate(writingItemAt: logURL, options: [.forMerging], error: &e)
							{ (_) in logFH.write(data) }
					}
			}
		} catch {
			BKLog.error("Setting up appearance log got \(error)")
		}
		if let w = writer {
			BKLog.set(loggerID: storage.absoluteString, logger: w)
		}
		defer { if let w = writer {
			done = true
			DispatchQueue.main.async
				{ BKLog.clear(loggerID: self.storage.absoluteString) }
		} }
	#endif

		do {
			let dataData = try JSONDecoder().decode(BrandData.self, from: json)
			dataData.setStorage(storage)
			self.data = dataData
			self.sequence = sequence + 1 // trigger re-apply brand by all observers
		} catch {
			BKLog.error("Loading brand data prevented by error: \(error)")
		}
	}

	open func unload() {
		coordinatingLoading = false
		self.data = nil
		self.sequence = 0 // !!!:
	}

	private var fileURL: URL {
		return storage.appendingPathComponent(Brand.fileName)
	}

	#if DEBUG
	open func printEditingPrompt() -> String {
		let url = fileURL
		let dir = url.deletingLastPathComponent()
		guard
			let components = URLComponents.init(url: dir, resolvingAgainstBaseURL: false)
		else { return "open \(fileURL)" }
		let prompt =
			"""
			••••••••••••••••••
			To edit appearance...
			1) Copy...
			\(components.path)
			2) Go to Finder, open new window
			3) Use Finder > Go > Go to Folder… (or type ⇧⌘G)
			4) Paste in the copied path
			5) Edit file \(url.lastPathComponent) in a text editor
			6) Open and watch for errors in "appearance.log" each time you save.
			--
			(or if accessing from Windows via a share, extract path from...
			\(components.path.replacingOccurrences(of: "/", with: "\\\\"))
			)
			••••••••••••••••••
			"""
		return prompt
	}
	#endif



	// MARK: - Metric

	public struct MetricKind : BrandAssetID {
		public static var assetKind:	BrandAssetKind	{ return .metric }
		public let rawValue:			String
		public init(_ rawValue:			String)			{ self.rawValue = rawValue }
		public init(rawValue:			String)			{ self.rawValue = rawValue }
	}

	open func metric(_ kind: MetricKind) -> CGFloat {
		if let brandData = data {
			if let entry = brandData.metrics[kind.rawValue] {
				return entry.resolved(using: brandData)
			} else {
				BKLog.error("brand.metric(\"\(kind.rawValue)\") could not find entry")
			}
		}
		return Brand.`default`.metric(kind)
	}

	// MARK: - Color

	public struct ColorKind : BrandAssetID {
		public static var assetKind:	BrandAssetKind	{ return .color }
		public let rawValue:			String
		public init(_ rawValue:			String)			{ self.rawValue = rawValue }
		public init(rawValue:			String)			{ self.rawValue = rawValue }
	}

	open func color(_ kind: ColorKind) -> Unified.Color {
		if let brandData = data {
			if let entry = brandData.colors[kind.rawValue] {
				return entry.resolved(using: brandData)
			} else {
				BKLog.error("brand.color(\"\(kind.rawValue)\") could not find entry")
			}
		}
		return Brand.`default`.color(kind)
	}

	// MARK: - Font

	public struct FontKind : BrandAssetID {
		public static var assetKind:	BrandAssetKind	{ return .font }
		public let rawValue:			String
		public init(_ rawValue:			String)			{ self.rawValue = rawValue }
		public init(rawValue:			String)			{ self.rawValue = rawValue }
	}

	open func font(_ kind: FontKind) -> Unified.Font {
		if let brandData = data {
			if let entry = brandData.fonts[kind.rawValue] {
				return entry.resolved(using: brandData)
			} else {
				BKLog.error("brand.font(\"\(kind.rawValue)\") could not find entry")
			}
		}
		return Brand.`default`.font(kind)
	}


	// MARK: - TextAttributes

	public struct TextAttributesKind : BrandAssetID {
		public static var assetKind:	BrandAssetKind	{ return .textAttributes }
		public let rawValue:			String
		public init(_ rawValue:			String)			{ self.rawValue = rawValue }
		public init(rawValue:			String)			{ self.rawValue = rawValue }
	}

	open func textAttributes(_ kind: TextAttributesKind) -> Unified.TextAttributes {
		if let brandData = data {
			if let entry = brandData.textAttributes[kind.rawValue] {
				return entry.resolved(using: brandData)
			} else {
				BKLog.error("brand.textAttributes(\"\(kind.rawValue)\") could not find entry")
			}
		}
		return Brand.`default`.textAttributes(kind)
	}

	open func applyTextAttributes(_ kind: TextAttributesKind, to view: Unified.View, withUpdatedText t: String? = nil) {
		let ta = textAttributes(kind)
		switch view {
			case let l as UILabel:
				l.attributedText = NSAttributedString(string: t ?? l.text ?? "", attributes: ta)
			case let f as UITextView:
				f.attributedText = NSAttributedString(string: t ?? f.text ?? "", attributes: ta)
			case let f as Unified.TextField:
				f.defaultTextAttributes = ta
				f.attributedText = NSAttributedString(string: t ?? f.text ?? "", attributes: ta)
			default:
				break
		}
	}

	open func applyTextAttributes(_ kind: TextAttributesKind, to views: [Unified.View]) {
		views.forEach
			{ applyTextAttributes(kind, to: $0) }
	}


	// MARK: - Placement

	public struct PlacementKind : BrandAssetID {
		public static var assetKind:	BrandAssetKind	{ return .placement }
		public let rawValue:			String
		public init(_ rawValue:			String)			{ self.rawValue = rawValue }
		public init(rawValue:			String)			{ self.rawValue = rawValue }
	}

	open func placement(_ kind: PlacementKind) -> Brand.Placement {
		if let brandData = data {
			if let entry = brandData.placements[kind.rawValue] {
				return entry
			} else {
				BKLog.error("brand.placement(\"\(kind.rawValue)\") could not find entry")
			}
		}
		return Brand.`default`.placement(kind)
	}

	// MARK: - Image

	public struct ImageKind : BrandAssetID {
		public static var assetKind:	BrandAssetKind	{ return .image }
		public let rawValue:			String
		public init(_ rawValue:			String)			{ self.rawValue = rawValue }
		public init(rawValue:			String)			{ self.rawValue = rawValue }
	}

	open func image(_ kind: ImageKind) -> Unified.Image {
		if let brandData = data {
			if let entry = brandData.images[kind.rawValue] {
				return entry.resolved(using: brandData)
			} else {
				BKLog.error("brand.image(\"\(kind.rawValue)\") could not find entry")
			}
		}
		return Brand.`default`.image(kind)
	}

	open func loadImage(_ kind: ImageKind, into imageView: Unified.ImageView) {
		if let brandData = data {
			if let entry = brandData.images[kind.rawValue] {
				let image = entry.resolved(using: brandData)
				imageView.image = image
				if let contentMode = entry.contentMode {
					imageView.contentMode = contentMode.viewContentMode
					if contentMode.constrainContainerAspect {
						Placement.constrain(view: imageView, toAspect: image.size)
					}
				}
				if let pn = entry.placement, let placement = brandData.placements[pn] {
					placement.apply(to: imageView)
				}
				return
			} else {
				BKLog.error("brand.image(\"\(kind.rawValue)\") could not find entry")
			}
		}
		Brand.`default`.loadImage(kind, into: imageView)
	}

	// MARK: - Button Style

	public struct ButtonStyleKind : BrandAssetID {
		public static var assetKind:	BrandAssetKind	{ return .buttonStyle }
		public let rawValue:			String
		public init(_ rawValue:			String)			{ self.rawValue = rawValue }
		public init(rawValue:			String)			{ self.rawValue = rawValue }
	}

	open func buttonStyle(_ kind: ButtonStyleKind) -> ButtonStyle {
		if let brandData = data {
			if let entry = brandData.buttonStyles[kind.rawValue] {
				return entry.resolved(using: brandData)
			} else {
				BKLog.error("brand.buttonStyles(\"\(kind.rawValue)\") could not find entry")
			}
		}
		return Brand.`default`.buttonStyle(kind)
	}

	open func applyButtonStyle(_ kind: ButtonStyleKind, to button: Unified.Button, withUpdatedText t: String? = nil, forStates: [UIControl.State]? = nil) {
		let bs = buttonStyle(kind)
		let states: [UIControl.State] = [.normal, .highlighted, .disabled, .selected]
		for state in states {
			guard nil == forStates || true == forStates?.contains(state) else { continue }
			guard let style = bs.stateStyles[state] else { continue }
			if	let ta = style.titleAttributes,
				let s = t ?? button.title(for: state) ?? button.title(for: .normal) {
				button.setAttributedTitle(NSAttributedString(string: s, attributes: ta), for: state)
			}
			button.setImage(style.titleImage, for: state)
			button.setBackgroundImage(style.backgroundImage, for: state)
		}
		if let insets = bs.contentInsets {
			button.contentEdgeInsets = insets
		}
		if let tintColor = bs.tintColor {
			button.tintColor = tintColor
		}
		if bs.reverseIconSide != (button.transform.a == -1) {
			let flipHorz = CGAffineTransform(scaleX: -1, y: 1)
			button.transform = button.transform.concatenating(flipHorz)
			if let view = button.titleLabel, bs.reverseIconSide != (view.transform.a == -1) {
				view.transform = view.transform.concatenating(flipHorz)
			}
			if let view = button.imageView, bs.reverseIconSide != (view.transform.a == -1) {
				view.transform = view.transform.concatenating(flipHorz)
			}
		}
	}

	open func applyButtonStyle(_ kind: ButtonStyleKind, to buttons: [Unified.Button]) {
		buttons.forEach
			{ applyButtonStyle(kind, to: $0) }
	}

	// MARK: - Parameter

	public struct ParameterKind : BrandAssetID {
		public static var assetKind:	BrandAssetKind	{ return .metric }
		public let rawValue:			String
		public init(_ rawValue:			String)			{ self.rawValue = rawValue }
		public init(rawValue:			String)			{ self.rawValue = rawValue }
	}

	fileprivate struct ParameterAccessor : BrandParameterAccessor {
		let entry:			BrandData.CustomParametersEntry
		let brand:			Brand
		let prefix:			(String)->String
	}

	open func parameterAccessor(_ kind: ParameterKind, indirect: Bool = true) -> BrandParameterAccessor {
		if let brandData = data {
			if var parameter = brandData.otherParameters[kind.rawValue] {
				while indirect, case .string(let s) = parameter.raw {
					guard let p = brandData.otherParameters[s] else { break }
					parameter = p
				}
				return ParameterAccessor(entry: parameter, brand: self, prefix: {$0})
			} else {
				BKLog.error("brand.parameter(\"\(kind.rawValue)\") could not find entry")
			}
		}
		return Brand.`default`.parameterAccessor(kind)
	}

	fileprivate func indirectParameterAccessor(at keyPath: String, in pa: BrandParameterAccessor)
	 -> BrandParameterAccessor? {
		guard let brandData = data else { return nil }
		var result: BrandParameterAccessor? = nil
	 	var a = pa
	 	while let s = a.string(at: keyPath), let p = brandData.otherParameters[s] {
			a = ParameterAccessor(entry: p, brand: self, prefix: {$0})
			result = a
		}
		return result
	}

	open func parameter(_ kind: ParameterKind) -> AnyJSONObject {
		if let brandData = data {
			if let parameter = brandData.otherParameters[kind.rawValue] {
				return parameter.raw
			} else {
				BKLog.error("brand.parameter(\"\(kind.rawValue)\") could not find entry")
			}
		}
		return Brand.`default`.parameter(kind)
	}
}



// MARK: -
public protocol BrandParameterAccessor {
	var brand: Brand { get }
	func object(at keyPath: String) -> AnyJSONObject?
	func string(at keyPath: String) -> String?
	func int(at keyPath: String) -> Int?
	func float(at keyPath: String) -> CGFloat?
	func floatArray(at keyPath: String) -> [CGFloat]?
	func point(at keyPath: String) -> CGPoint?
	func size(at keyPath: String) -> CGSize?
	func insets(at keyPath: String) -> UIEdgeInsets?
	func color(at keyPath: String) -> UIColor?
	func accessor(at keyPath: String) -> BrandParameterAccessor // where a substructure expects to use an accessor
}



extension BrandParameterAccessor {
	public func assetID<K : BrandAssetID>(at keyPath: String) -> K? {
		if let s = string(at: keyPath) {
			return K(rawValue: s)
		}
		return nil
	}
}



// MARK: -
extension Brand.ParameterAccessor {
	func object(at keyPath: String) -> AnyJSONObject? 	{ return entry.raw.value(at: prefix(keyPath)) }
	func string(at keyPath: String) -> String? 			{ return entry.string(at: prefix(keyPath), using: brand) }
	func int(at keyPath: String) -> Int? 				{ return entry.int(at: prefix(keyPath), using: brand) }
	func float(at keyPath: String) -> CGFloat? 			{ return entry.float(at: prefix(keyPath), using: brand) }
	func floatArray(at keyPath: String) -> [CGFloat]? 	{ return entry.floatArray(at: prefix(keyPath), using: brand) }
	func point(at keyPath: String) -> CGPoint? 			{ return entry.point(at: prefix(keyPath), using: brand) }
	func size(at keyPath: String) -> CGSize? 			{ return entry.size(at: prefix(keyPath), using: brand) }
	func insets(at keyPath: String) -> UIEdgeInsets? 	{ return entry.insets(at: prefix(keyPath), using: brand) }
	func color(at keyPath: String) -> UIColor? 			{ return entry.color(at: prefix(keyPath), using: brand) }
	func accessor(at keyPath: String) -> BrandParameterAccessor {
		guard !keyPath.isEmpty else { return self }
		if let accessor = brand.indirectParameterAccessor(at: keyPath, in: self) { return accessor }
		let p = prefix(keyPath).appending(".")
		return Brand.ParameterAccessor.init(entry: entry, brand: brand, prefix: {p.appending($0)})
	}
}



// MARK: -
extension Brand : NSFilePresenter
{
	public var presentedItemURL: URL? {
		return fileURL
	}

	public var presentedItemOperationQueue: OperationQueue {
		return .main
	}

	public func presentedItemDidChange() {
		DispatchQueue.main.async
			{ self.reload() }
	}
}



