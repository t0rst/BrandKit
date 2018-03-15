/*
	BrandData.swift
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



fileprivate protocol BrandDataEntry
{
	associatedtype Value
	static var kind: BrandData.Kind { get }
	func cacheIsValid() -> Bool
	func loadCache(using: BrandData)
	func resolved(using: BrandData) -> Value
}



extension BrandDataEntry
{
	func loadCache(using: BrandData) {
		if !cacheIsValid() {
			_ = resolved(using: using)
		}
	}
}



// MARK: -
struct BrandData : Codable
{
	var version: Int?				= 0
	// version is mandatory for the root entry, but can be ignored by groups

	var metrics						= MetricsByName()
	var colors						= ColorsByName()
	var fonts						= FontsByName()
	var textAttributes				= TextAttributesByName()
	var placements					= PlacementsByName()
	var images						= ImagesByName()
	var buttonStyles				= ButtonStylesByName()
	var otherParameters				= ParametersByName()

	/// Groups allow convenient grouping of brand data per area of application; otherwise the
	/// entries in each kind get too bulky and entries across kinds that must work together sit
	/// too far apart to easily maintain. At the end of decoding, all entries in a group are
	/// flattened into the parent brand data by appending their entries to thos of the parent, but
	/// with name prefixed by the group name and a period.
	var groups: [String:BrandData]?	= nil

	var context						= CacheEntry<Context>()

	struct Context {
		var storage:				URL? = nil
	}

	func setStorage(_ storage: URL) {
		context.set(payload: BrandData.Context(storage: storage))
	}

	enum CodingKeys : String, CodingKey {
		case version
		case metrics, colors, fonts, textAttributes, placements, images, buttonStyles, otherParameters
		case groups
	//	case context - omit
	}

	typealias MetricsByName =		[String:MetricEntry]
	typealias ColorsByName =		[String:ColorEntry]
	typealias FontsByName =			[String:FontEntry]
	typealias TextAttributesByName = [String:TextAttributesEntry]
	typealias PlacementsByName =	[String:Brand.Placement]
	typealias ImagesByName =		[String:ImageEntry]
	typealias ButtonStylesByName =	[String:ButtonStyleEntry]
	typealias ParametersByName =	[String:CustomParametersEntry]

	enum Kind { case metric, color, font, placement, image, textAttributes, buttonStyle, customParameters }
	typealias KindWithKey = (kind: Kind, key: String)

	// MARK: -
	class CacheEntry<Payload>
	{
		private(set) var payload:	Payload? = nil
		private(set) var valid:		Bool = false

		func isLoaded() -> Bool		{ return nil != payload }
		func isValid() -> Bool		{ return valid }

		func reset()				{ payload = nil ; valid = false }
		func set(payload p: Payload?, valid v: Bool = true) { payload = p ; valid = v && nil != p }

		func depends(on kind: Kind, withKey: String)	{}
		func depends(on many: [KindWithKey])	{}
	}

	// MARK: -
	struct MetricEntry : BrandDataEntry
	{
		static var kind =			Kind.metric

		let raw:					String

		typealias Cache =			CacheEntry<CGFloat>
		private var _cache =		Cache()
		fileprivate func			cacheIsValid() -> Bool { return _cache.isValid() }

		func resolved(using others: BrandData) -> CGFloat {
			return Brand.resolveMetric(self, into: _cache, using: others)
		}

		init(raw: String) { self.raw = raw }
	}

	// MARK: -
	struct ColorEntry : BrandDataEntry
	{
		static var kind =			Kind.color

		let raw:					String

		typealias Cache =			CacheEntry<Unified.Color>
		private var _cache =		Cache()
		fileprivate func			cacheIsValid() -> Bool { return _cache.isValid() }
		func resolved(using others: BrandData) -> Unified.Color {
			return Brand.resolveColor(self, into: _cache, using: others)
		}
	}

	// MARK: -
	struct FontEntry : BrandDataEntry, Codable
	{
		static var kind =			Kind.font

		let basedOn:				String?			// name of other FontEntry
		let family:					String?
		let face:					String?
		let size:					String?			// name of metric
		let attributes:				AnyJSONObject?	// advanced customisation
	//	let useFor:					String?			// ==> UIFontTextStyle on iOS
	//	...only useful on iOS and only for dynamic type size; better accessed as special metric

		struct Payload {
			var descriptor:			Unified.FontDescriptor
			var font:				Unified.Font? = nil
		}
		typealias Cache =			CacheEntry<Payload>
		fileprivate var _cache =	Cache()
		fileprivate func			cacheIsValid() -> Bool { return _cache.isValid() }

		func resolved(using others: BrandData) -> Unified.Font {
			return Brand.resolveFont(self, into: _cache, using: others)
		}

		enum CodingKeys : String, CodingKey {
			case basedOn, family, face, size, attributes/*, useFor*/ // omit _cache
		}
	}

	// MARK: -
	struct TextAttributesEntry : BrandDataEntry, Codable
	{
		static var kind =			Kind.textAttributes

		let basedOn:				String?			// name of TextAttributesEntry this derives from
		let attributes:				AnyJSONObject?	// arbitrary dictionary of text attributes
													// - validated during resolve
													// - values check for match of named brand asset first before checking for inline value

		struct Payload {
			var attributes:			Unified.TextAttributes
			var tracking:			CGFloat? = nil // Em/1000
			// ...NSAttributedString does not support tracking (yeah, f**k the industry), but does
			// have a kern attribute which is absolute, whereas tracking is relative. So we keep a
			// separate record of tracking and then add the equivalent kern for the type size to the
			// attributes.
		}
		typealias Cache =			CacheEntry<Payload>
		fileprivate var _cache =	Cache()
		fileprivate func			cacheIsValid() -> Bool { return _cache.isValid() }

		func resolved(using others: BrandData) -> Unified.TextAttributes {
			return Brand.resolveTextAttributes(self, into: _cache, using: others)
		}

		enum CodingKeys : String, CodingKey {
			case basedOn, attributes // omit _cache
		}
	}

	// MARK: -
	typealias Placement = Brand.Placement
	typealias ContentMode = Brand.ContentMode
	typealias RelativeDimension = Brand.RelativeDimension

	struct PlacementEntry
	{
		let placementRules:			String?
		let auxiliaryViews:			String?
		let relativeDimensions:		[RelativeDimension]?

		typealias Cache =			CacheEntry<Placement>
		fileprivate var _cache =	Cache()
		fileprivate func			cacheIsValid() -> Bool { return _cache.isValid() }

	//	func resolved(using others: BrandData) -> Placement {
	//		return Brand.resolvePlacement(self, into: _cache, using: others)
	//	}
	}

/*
	/// An image together with information to ensure its desired placement. Use this with `Brand`
	/// function `applyImageWithPlacement(_:to:withPriorityReducedBy:)`
	///
	/// - `aspect` gives the Width:Height ratio to preserve when presenting. It can be different to
	/// image.size, e.g. where a temporary image is returned.
	/// - `nominalSize` gives target size to present if known. One or other ordinal may be zero, in
	/// which case derive from the orthogonal using `aspect`.
	/// - `alignmentInsets` gives the difference between nominal size and alignmentRect if any.
	/// Usually the edges of an image are used for aligment. However, some images are smaller than
	/// the target area they need to be presented in, e.g. a dot image to go in a button with
	/// standard size will often use less than the full area, or have bits of graphic detail that
	/// extend out of the main detail, e.g. a custom drop shadow; for such images, a set of
	/// alignmentInsets can be provided to specify the alignmentRect relative to the nominal size.
*/
	// MARK: -
	struct ImageEntry : BrandDataEntry
	{
		static var kind =			Kind.image

		let basedOn:				String?		// name of other ImageEntry this derives from
		// OR...
		let filePath:				String?		// path of file containing image, rel to brand folder
		// OR...
		struct SimpleBackground : Codable
		{
			let fillColor:		String?
			let strokeColor:	String?
			let lineWidth:		String?
			let cornerRadius:	String?
			let minimumWidth:	String?
			let minimumHeight:	String?
		}
		let makeBackground:			SimpleBackground?

		let alignmentInsets:		String?
		let contentMode:			ContentMode?	// alternatively specify inside placement
	#if os(iOS)
		let renderMode:				Unified.ImageRenderingMode?
	#elseif os(macOS)
	#endif
		let placement:				String?		// name of placement to apply to user of this image

		typealias Cache =			CacheEntry<Unified.Image>
		private var _cache =		Cache()
		fileprivate func			cacheIsValid() -> Bool { return _cache.isValid() }

		func resolved(using others: BrandData) -> Unified.Image {
			return Brand.resolveImage(self, into: _cache, using: others)
		}
	}

	// MARK: -
	struct ButtonStyleEntry : BrandDataEntry, Codable
	{
		static var kind =			Kind.buttonStyle

		struct StyleElementNames : Codable {
			let titleAttributes, titleImage, backgroundImage: String?
		}

		let normalStyle:			StyleElementNames?
		let highlightedStyle:		StyleElementNames?
		let disabledStyle:			StyleElementNames?
		let selectedStyle:			StyleElementNames?
		let contentInsets:			String?
		let tintColor:				String?
		let reverseIconSide:		Bool?

		typealias Cache =			CacheEntry<ButtonStyle>
		private var _cache =		Cache()
		fileprivate func			cacheIsValid() -> Bool { return _cache.isValid() }

		func resolved(using others: BrandData) -> ButtonStyle {
			return Brand.resolveButtonStyle(self, into: _cache, using: others)
		}

		enum CodingKeys : String, CodingKey {
			case normalStyle, highlightedStyle, disabledStyle, selectedStyle, contentInsets, tintColor, reverseIconSide // omit _cache
		}
	}

	// MARK: -
	struct CustomParametersEntry : BrandDataEntry
	{
		static var kind =			Kind.customParameters

		let raw:					AnyJSONObject

		typealias Values = [String:Any]
		typealias Cache =			CacheEntry<Values>
		private var _cache =		Cache()
		fileprivate func			cacheIsValid() -> Bool { return _cache.isValid() }

		func resolved(using others: BrandData) -> AnyJSONObject {
			return raw
		}
	}
}


// MARK: -
extension BrandData
{
	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		self.version			= try container.decodeIfPresent(Int.self, forKey: .version)
		self.metrics			= try container.decodeIfPresent(MetricsByName.self, forKey: .metrics) ?? [:]
		self.colors				= try container.decodeIfPresent(ColorsByName.self, forKey: .colors) ?? [:]
		self.fonts				= try container.decodeIfPresent(FontsByName.self, forKey: .fonts) ?? [:]
		self.textAttributes		= try container.decodeIfPresent(TextAttributesByName.self, forKey: .textAttributes) ?? [:]
		self.placements			= try container.decodeIfPresent(PlacementsByName.self, forKey: .placements) ?? [:]
		self.images				= try container.decodeIfPresent(ImagesByName.self, forKey: .images) ?? [:]
		self.buttonStyles		= try container.decodeIfPresent(ButtonStylesByName.self, forKey: .buttonStyles) ?? [:]
		self.otherParameters	= try container.decodeIfPresent(ParametersByName.self, forKey: .otherParameters) ?? [:]
		func merge<E>(from d: [String:E], prefixBy p: String, into: inout [String:E]) throws
		where E : BrandDataEntry { try merge(kind: "\(E.kind)", from: d, prefixBy: p, into: &into) }
		func merge<E>(kind: String, from d: [String:E], prefixBy: String, into: inout [String:E]) throws
		where E : Any {
			let renamed = d.map { return (prefixBy.appending($0.key), $0.value) }
			try into.merge(renamed) { (a: E, b: E) in
				throw DecodingError.dataCorruptedError(forKey: .groups, in: container, debugDescription: "Found duplicate \(kind) keys with values\nnew:\n\(a)\nexisting:\n\(b)")
			}
		}
		if let groups = try container.decodeIfPresent([String:BrandData].self, forKey: .groups) {
			for (name, data) in groups {
				let s = "\(name)."
				try merge(from: data.metrics, prefixBy: s, into: &self.metrics)
				try merge(from: data.colors, prefixBy: s, into: &self.colors)
				try merge(from: data.fonts, prefixBy: s, into: &self.fonts)
				try merge(from: data.textAttributes, prefixBy: s, into: &self.textAttributes)
				try merge(kind: "placements", from: data.placements, prefixBy: s, into: &self.placements)
				try merge(from: data.images, prefixBy: s, into: &self.images)
				try merge(from: data.buttonStyles, prefixBy: s, into: &self.buttonStyles)
				try merge(kind: "otherParameters", from: data.otherParameters, prefixBy: s, into: &self.otherParameters)
			}
		}
		// ...and (for now) we discard the nested instances in groups
	}
}



// MARK: -
extension BrandData
{
/*
	fileprivate func fetchResolvedEntry<T>(named name: String, forKey: String, ofKind: BrandData.Kind) -> T?
	where T : BrandDataEntry
	{
		var entry: T?
		switch T.kind {
			case .color:			entry = colors[name]
			case .metric:			entry = metrics[name]
			case .font:				entry = fonts[name]
			case .image:			entry = images[name]
			case .textAttributes:	entry = textAttributes[name]
			default:				return nil
		}
		guard let fetched = entry
		else { BKLog.error("\(ofKind) couldn't find \(forKey) entry named \"\(name)\"") ; return nil }
		fetched.loadCache(using: self)
		guard fetched.cacheIsValid()
		else { BKLog.error("\(ofKind) wants to use \(forKey) entry named \"\(name)\", which is not valid") ; return nil }
		return fetched
	}
*/

	fileprivate func fetchResolvedColorEntry(_ name: String, forKey: String, ofKind: BrandData.Kind) -> ColorEntry?
	{
		let entry = colors[name]
		guard let fetched = entry
		else { BKLog.error("\(ofKind) couldn't find \(forKey) entry named \"\(name)\"") ; return nil }
		fetched.loadCache(using: self)
		guard fetched.cacheIsValid()
		else { BKLog.error("\(ofKind) wants to use \(forKey) entry named \"\(name)\", which is not valid") ; return nil }
		return fetched
	}

	fileprivate func fetchResolvedMetricEntry(_ name: String, forKey: String, ofKind: BrandData.Kind) -> MetricEntry?
	{
		let entry = metrics[name]
		guard let fetched = entry
		else { BKLog.error("\(ofKind) couldn't find \(forKey) entry named \"\(name)\"") ; return nil }
		fetched.loadCache(using: self)
		guard fetched.cacheIsValid()
		else { BKLog.error("\(ofKind) wants to use \(forKey) entry named \"\(name)\", which is not valid") ; return nil }
		return fetched
	}

	fileprivate func fetchResolvedFontEntry(_ name: String, forKey: String, ofKind: BrandData.Kind) -> FontEntry?
	{
		let entry = fonts[name]
		guard let fetched = entry
		else { BKLog.error("\(ofKind) couldn't find \(forKey) entry named \"\(name)\"") ; return nil }
		fetched.loadCache(using: self)
		guard fetched.cacheIsValid()
		else { BKLog.error("\(ofKind) wants to use \(forKey) entry named \"\(name)\", which is not valid") ; return nil }
		return fetched
	}

	fileprivate func fetchResolvedTextAttributesEntry(_ name: String, forKey: String, ofKind: BrandData.Kind) -> TextAttributesEntry?
	{
		let entry = textAttributes[name]
		guard let fetched = entry
		else { BKLog.error("\(ofKind) couldn't find \(forKey) entry named \"\(name)\"") ; return nil }
		fetched.loadCache(using: self)
		guard fetched.cacheIsValid()
		else { BKLog.error("\(ofKind) wants to use \(forKey) entry named \"\(name)\", which is not valid") ; return nil }
		return fetched
	}

	fileprivate func fetchResolvedImageEntry(_ name: String, forKey: String, ofKind: BrandData.Kind) -> ImageEntry?
	{
		let entry = images[name]
		guard let fetched = entry
		else { BKLog.error("\(ofKind) couldn't find \(forKey) entry named \"\(name)\"") ; return nil }
		fetched.loadCache(using: self)
		guard fetched.cacheIsValid()
		else { BKLog.error("\(ofKind) wants to use \(forKey) entry named \"\(name)\", which is not valid") ; return nil }
		return fetched
	}
}



// MARK: - Metrics
extension BrandData.MetricEntry : Codable
{
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		raw = try container.decode(String.self)
		if let key = container.codingPath.last?.stringValue, key.contains(" "), !raw.isEmpty {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "The coding key \"\(key)\" containing this metric entry may not contain spaces.")
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(raw)
	}
}



extension Brand
{
	public static let kInvalidMetric = CGFloat.pi // not entirely useful, and (probably) doesnt cause crashes

	static func resolveMetric(_ entry: BrandData.MetricEntry, into cache: BrandData.MetricEntry.Cache, using others: BrandData) -> CGFloat
	{
		if cache.isLoaded(), let m = cache.payload {
			return m
		}

		cache.set(payload: kInvalidMetric, valid: false)
		if entry.raw.isEmpty { // tolerated as value of a key used as a comment, but should never be used
			return kInvalidMetric
		}

		if let (value, deps) = extractOneMetric(from: entry.raw, using: others) {
			cache.depends(on: deps)
			cache.set(payload: value)
			return value
		} else {
			return kInvalidMetric
		}
	}

	static func extractMetrics(count requested: Int = Int.max, from s: String, using others: BrandData, expecting: String)
	-> (values: [CGFloat], dependees: [BrandData.KindWithKey])? {
		let extractAll = requested == Int.max
		var values = [CGFloat]()
		var dependees = [BrandData.KindWithKey]()
		var remaining: String? = s

		while values.count < requested {
			guard let r = remaining else { break }
			remaining = nil
			let parts = r.split(separator: "/", maxSplits: 1, omittingEmptySubsequences: false)
			let head = String(parts[0])
			switch head {
				case "add", "mul", "min", "max", "switch":
					let minArgsCount = head == "switch" ? 2 : 1
					guard
						let rem = parts.at(1),
						let (args, deps) = extractMetrics(from: String(rem), using: others, expecting: expecting),
						args.count > minArgsCount
					else { BKLog.error("While \(expecting), found insufficient parameters to \"\(head)\" in \"\(s)\"") ; return nil }
					let value: CGFloat
					switch head {
						case "add": value = args.reduce(CGFloat(0)) { $0 + $1 }
						case "mul": value = args.reduce(CGFloat(1)) { $0 * $1 }
						case "min": value = args.min() ?? 0
						case "max": value = args.max() ?? 0
						case "switch":
							if let i = Int(exactly: args[0]), i < args.count - 1 {
								value = args[i+1]
							} else {
								value = args.last ?? 0
							}
						default:
							BKLog.error("Unrecognised metric format \"\(head)\"")
							return nil
					}
					dependees.append(contentsOf: deps)
					values.append(value)
					// add/mul/min/max/switch consume all remaining
				case "":
					values.append(0)
					if let rem = parts.at(1) {
						remaining = String(rem)
					}
				case "named":
					guard let p1 = parts.at(1)
					else { BKLog.error("While \(expecting), encountered missing name in \"\(s)\".") ; return nil }
					let name = String(p1)
					if let otherEntry = others.metrics[name] {
						dependees.append((.metric, name))
						let value = otherEntry.resolved(using: others)
						guard otherEntry.cacheIsValid()
						else { BKLog.error("While \(expecting), tried to use invalid metric entry \"\(name)\".") ; return nil }
						values.append(value)
					} else {
						BKLog.error("While \(expecting), could not recognise value or expression \"\(name)\" within \"\(s)\".")
						return nil
					}
				default:
					if let f = Double(head) {
						values.append(CGFloat(f))
					} else if let otherEntry = others.metrics[head] {
						dependees.append((.metric, head))
						let value = otherEntry.resolved(using: others)
						guard otherEntry.cacheIsValid()
						else { BKLog.error("While \(expecting), tried to use invalid metric entry \"\(head)\".") ; return nil }
						values.append(value)
					} else {
						BKLog.error("While \(expecting), could not recognise value or expression \"\(head)\" within \"\(s)\".")
						return nil
					}
					if let rem = parts.at(1) {
						remaining = String(rem)
					}
			}
		}
		
		if let rem = remaining {
			BKLog.error("While \(expecting), did not process remaining expression \"\(rem)\" out of entire \"\(s)\".")
			return nil
		}
		
		if !extractAll && values.count < requested {
			BKLog.error("While \(expecting), could not extract sufficient values out of \"\(s)\".")
			return nil
		}

		return (values, dependees)
	}

	static func extractOneMetric(from: String, using others: BrandData, expecting: String = "")
	-> (value: CGFloat, dependees: [BrandData.KindWithKey])? {
		let expect = expecting.isEmpty ? "extracting a metric" : expecting
		let s = from.replacingOccurrences(of: " ", with: "")
		if	let (values, dependees) = extractMetrics(count: 1, from: s, using: others, expecting: expect),
			!values.isEmpty {
			return (values[0], dependees)
		}
		return nil
	}

	static func extractMetric(forEach strings: [String], using others: BrandData, expecting: String = "")
	-> (values: [CGFloat], dependees: [BrandData.KindWithKey])? {
		let expect = expecting.isEmpty ? "extracting a metric" : expecting
		var values = [CGFloat]()
		var dependees = [BrandData.KindWithKey]()
		for string in strings {
			let s = string.replacingOccurrences(of: " ", with: "")
			guard let (vals, deps) = extractMetrics(count: 1, from: s, using: others, expecting: expect)
			else { return nil }
			dependees.append(contentsOf: deps)
			values.append(contentsOf: vals)
		}
		return (values, dependees)
	}

	static func extractOneMetric(from jso: AnyJSONObject, using others: BrandData, expecting: String = "")
	-> (value: CGFloat, dependees: [BrandData.KindWithKey])? {
		switch jso {
			case .string(let s):
				return extractOneMetric(from: s, using: others, expecting: expecting)
			default:
				if let d = jso.asDouble {
					return (CGFloat(d), [])
				}
		}
		return nil
	}

	static func extractMetrics(count requested: Int = Int.max, from jso: AnyJSONObject, using others: BrandData, expecting: String = "")
	-> (values: [CGFloat], dependees: [BrandData.KindWithKey])? {

		var values = [CGFloat]()
		var dependees = [BrandData.KindWithKey]()
		switch jso {
			case .array(let a):
				for jso in a {
					guard let (value, deps) = extractOneMetric(from: jso, using: others, expecting: expecting)
					else { return nil }
					values.append(value)
					dependees.append(contentsOf: deps)
				}
			case .string(let s):
				guard let (vals, deps) = extractMetrics(count: requested, from: s, using: others, expecting: expecting)
				else { return nil }
				values.append(contentsOf: vals)
				dependees.append(contentsOf: deps)
			default:
				guard let value = jso.asDouble
				else { return nil }
				values.append(CGFloat(value))
		}
		guard values.count == requested || requested == Int.max
		else { return nil }
		return (values, dependees)
	}
}



// MARK: - Colors
extension BrandData.ColorEntry : Codable
{
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		raw = try container.decode(String.self)
		if let key = container.codingPath.last?.stringValue, key.contains(" ") {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "The coding key \"\(key)\" containing this color entry may not contain spaces.")
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(raw)
	}
}



extension Brand
{
	public static let kInvalidColor = Unified.Color(red: 1.0, green: 0.0, blue: 0.0, alpha: 0.8)

	static func resolveColor(_ entry: BrandData.ColorEntry, into cache: BrandData.ColorEntry.Cache, using others: BrandData) -> Unified.Color
	{
		if cache.isLoaded(), let c = cache.payload {
			return c
		}

		enum Format : String {
			case rgb		// rgb/173/82/76, rgb/.7/.3/.5
			case rgba		// rgba/173/82/76/255, rgba/.7/.3/.5/1,
			case hsb		// hsba/0/.9/.7/1
			case hsba		// hsba/0/.9/.7/1
			case w			// wa/.5
			case wa			// wa/.5/1
			case web		// web/FFCCAA
			case named		// named/name_of_another_color
			func componentCount() -> Int { switch self {
				case .rgba, .hsba:		return 4
				case .rgb, .hsb:		return 3
				case .wa:				return 2
				case .w, .web, .named:	return 1
			} }
		}

		cache.set(payload: Brand.kInvalidColor, valid: false)

		let raw = entry.raw.replacingOccurrences(of: " ", with: "")
		let parts = raw.split(separator: "/", omittingEmptySubsequences: false)

		guard let formatStr = parts.first, let format = Format(rawValue: String(formatStr))
		else { BKLog.error("Unrecognised format in colour \"\(entry.raw)\"") ; return Brand.kInvalidColor }

		guard parts.count - 1 == format.componentCount()
		else { BKLog.error("Inconsistent #parts in colour \"\(entry.raw)\"") ; return Brand.kInvalidColor }

		let remaining = parts.dropFirst()
		var value = Brand.kInvalidColor
		var components = [CGFloat]()
		var haveFractional = false
		var have255Range = false

		switch format {
			case .named:
				let name = String(parts[1])
				if let otherEntry = others.colors[name] {
					cache.depends(on: .color, withKey: name)
					value = otherEntry.resolved(using: others)
				} else { switch name { // standard colour?
					case "black":		value = .black
					case "darkGray":	value = .darkGray
					case "lightGray":	value = .lightGray
					case "white":		value = .white
					case "gray":		value = .gray
					case "red":			value = .red
					case "green":		value = .green
					case "blue":		value = .blue
					case "cyan":		value = .cyan
					case "yellow":		value = .yellow
					case "magenta":		value = .magenta
					case "orange":		value = .orange
					case "purple":		value = .purple
					case "brown":		value = .brown
					case "clear":		value = .clear
					default:
						BKLog.error("Colour \"\(entry.raw)\" could not find referenced colour \"\(name)\"")
						return Brand.kInvalidColor
				} }
			case .web:
				have255Range = true
				let hex = String(parts[1])
				var idx0 = hex.startIndex
				while let idx2 = hex.index(idx0, offsetBy: 2, limitedBy: hex.endIndex) {
					let sub = hex[idx0..<idx2]
					guard let i = Int(sub, radix: 16)
					else { BKLog.error("Invalid component \"\(String(sub))\" in colour \"\(entry.raw)\"") ; return Brand.kInvalidColor }
					components.append(CGFloat(i))
					idx0 = idx2
					if components.count == 4 { break }
				}
				guard idx0 == hex.endIndex
				else { BKLog.error("Too many components in colour \"\(entry.raw)\"") ; return Brand.kInvalidColor }
				guard components.count == 3 || components.count == 4
				else { BKLog.error("Expect three or four components in colour \"\(entry.raw)\"") ; return Brand.kInvalidColor }
				if components.count == 3 { components.append(CGFloat(255)) }
			default:
				let a = remaining.map {String($0)}
				guard
					let (values, dependees) = extractMetric(forEach: a, using: others, expecting: "resolving color with format \(format)"),
					values.count == a.count
				else { return kInvalidColor }
				cache.depends(on: dependees)
				for (f, sub) in zip(values, a) {
					let isAlphaComponent = components.count == ((format == .w || format == .wa) ? 1 : 3)
					if sub.isEmpty {
						components.append(isAlphaComponent ? (have255Range ? 255.0 : 1.0) : 0.0)
						continue
					}
					guard f >= 0, f <= 255.0
					else { BKLog.error("Invalid component \"\(String(sub))\" in colour \"\(entry.raw)\"") ; return Brand.kInvalidColor }
					have255Range = have255Range || f > 1.0
					haveFractional = haveFractional || (f > 0.0 && f < 1.0)
					components.append(f)
				}
				guard !(haveFractional && have255Range)
				else { BKLog.error("Inconsistent component types in colour \"\(entry.raw)\"") ; return Brand.kInvalidColor }
				if components.count == 1 || components.count == 3 {
					components.append(CGFloat(have255Range ? 255 : 1))
				}
				break
		}

		if !components.isEmpty {
			if have255Range {
				components = components.map { $0 / 255.0 }
			}
			switch components.count {
				case 2:
					value = Unified.Color.init(white: components[0], alpha: components[1])
				case 4:
					if format == .hsb || format == .hsba {
						value = Unified.Color(hue: components[0], saturation: components[1], brightness: components[2], alpha: components[3])
					} else {
						value = Unified.Color(red: components[0], green: components[1], blue: components[2], alpha: components[3])
					}
				default:
					BKLog.fault("Error parsing colour \"\(entry.raw)\"")
					return Brand.kInvalidColor
			}
		}

		cache.set(payload: value)
		return value
	}

	static func extractColor(from s: String, using others: BrandData, expecting: String)
	-> (color: Unified.Color, dependees: [BrandData.KindWithKey])? {
		return nil
	}
}



// MARK: - Fonts
extension Brand
{
	public static let kInvalidFontDescriptor = Unified.FontDescriptor(name: "Courier-BoldOblique", size: 21)
#if os(iOS)
	public static let kInvalidFont = Unified.Font(descriptor: kInvalidFontDescriptor, size: 21)
#elseif os(macOS)
	public static let kInvalidFont = Unified.Font(descriptor: kInvalidFontDescriptor, size: 21) ?? Unified.Font()
#endif

	static func resolveFont(_ entry: BrandData.FontEntry, into cache: BrandData.FontEntry.Cache, using others: BrandData) -> Unified.Font
	{
		if cache.isLoaded(), let f = cache.payload?.font {
			return f
		}

		let invalidPayload = BrandData.FontEntry.Payload(descriptor: Brand.kInvalidFontDescriptor, font: Brand.kInvalidFont)
		cache.set(payload: invalidPayload, valid: false)

		var fd:				Unified.FontDescriptor
		var preferredSize:	CGFloat = 17.0

	/*	Only useful on iOS, and only for dynamic type size, as they prevent custom font choice.

		var usage =			UIFontTextStyle.body
	
		if let s = entry.useFor { switch s {
			case "largeTitle":
				if #available(iOS 11.0, *) {
					usage = .largeTitle
				} else {
					fallthrough
				}
			case "title1":			usage = .title1
			case "title2":			usage = .title2
			case "title3":			usage = .title3
			case "headline":		usage = .headline
			case "subheadline":		usage = .subheadline
			case "body":			usage = .body
			case "callout":			usage = .callout
			case "footnote":		usage = .footnote
			case "caption1":		usage = .caption1
			case "caption2":		usage = .caption2
			default:
				BKLog.error("Value \"\(s)\" is not a recognised option for \"useFor\" (use body, title1/2/3, caption1/2, (sub)headline, footnote, callout, largeTitle)")
				return Brand.kInvalidFont
		} }
	*/

		if let name = entry.basedOn {
			guard let base = others.fonts[name]
			else { BKLog.error("Font based on other couldn't find entry named \"\(name)\"") ; return Brand.kInvalidFont }
			cache.depends(on: .font, withKey: name)
			_ = base.resolved(using: others)
			guard base.cacheIsValid(), let baseFD = base._cache.payload?.descriptor
			else { BKLog.error("Font based on font \"\(name)\" which is not valid") ; return Brand.kInvalidFont }
			fd = baseFD //.addingAttributes(attributes)
		} else {
		//	fd = Unified.FontDescriptor.preferredFontDescriptor(withTextStyle: usage)
		//	...no good. Sticks permantly to system font, change requests ignored.
			fd = Unified.FontDescriptor()
		}

		if let a = entry.attributes?.asObject as? Dictionary<String, Any> {
			var reject = false
			let pairs = a.flatMap { (kv) -> (Unified.FontDescriptorAttributes.Key,Any)? in
				let an: Unified.FontDescriptor.AttributeName
				// FIXME: reject incompatible value types
				switch kv.key {
					// Because the actual attribute dictionary keys are big and cumbersome, we
					// accept the constant names used in the swift def and replace with actual constants
					case "family":			an = .family			// == "NSFontFamilyAttribute"
					case "face":			an = .face				// == "NSFontFaceAttribute"
					case "name":			an = .name				// == "NSFontNameAttribute"
					case "size":			an = .size				// == "NSFontSizeAttribute"
					case "visibleName":		an = .visibleName		// == "NSFontVisibleNameAttribute"
					case "matrix":			an = .matrix			// == "NSFontMatrixAttribute"
					case "characterSet":	an = .characterSet		// == "NSCTFontCharacterSetAttribute"
					case "traits":			an = .traits			// == "NSCTFontTraitsAttribute"
					case "fixedAdvance":	an = .fixedAdvance		// == "NSCTFontFixedAdvanceAttribute"
					case "featureSettings": an = .featureSettings	// == "NSCTFontFeatureSettingsAttribute"
						// ...array of dictionaries containing featureTypeK&V and featureSelectorK&V, e.g.:
						//	[ [ UIFontFeatureTypeIdentifierKey : kUpperCaseType,
            			//		UIFontFeatureSelectorIdentifierKey : kUpperCaseSmallCapsSelector ]  ]
					case "textStyle":
						#if os(iOS)
							an = .textStyle			// == "NSCTFontUIUsageAttribute"
						#elseif os(macOS)
							return nil
						#endif
					case "symbolic":
						#if os(iOS)
							an = .symbolic			// == "NSCTFontSymbolicTrait"
						#elseif os(macOS)
							return nil
						#endif
					default:
						if kv.key.hasPrefix("!") {
							an = Unified.FontDescriptor.AttributeName(String(kv.key.dropFirst()))
						} else {
							an = Unified.FontDescriptor.AttributeName(kv.key)
							BKLog.error("Unrecognised font attribute \"\(kv.key)\"")
							reject = true
						}
				}
				return (an, kv.value)
			}
			if reject { return Brand.kInvalidFont }
			let attributes = Unified.FontDescriptorAttributes(uniqueKeysWithValues: pairs)
			if let size = attributes[.size] as? CGFloat {
				preferredSize = size
			}
			fd = fd.addingAttributes(attributes)
		}

		if let f = entry.family, !f.isEmpty {
			fd = fd.withFamily(f)
		}

		if let f = entry.face, !f.isEmpty {
			fd = fd.withFace(f)
		}

		if let name = entry.size {
			guard let metricEntry = others.metrics[name]
			else { BKLog.error("Font could not find metric for size \"\(name)\"") ; return Brand.kInvalidFont }
			cache.depends(on: .metric, withKey: name)
			let size = metricEntry.resolved(using: others)
			guard metricEntry.cacheIsValid()
			else { BKLog.error("Font uses metric for size \"\(name)\" which is not valid") ; return Brand.kInvalidFont }
			preferredSize = size
			fd = fd.withSize(size)
		}

		guard let expectPSName = fd.object(forKey: .name) as? String
		else { BKLog.error("Name of font not recognised. Check that spaces and order within family/face/name are correct in \(entry) -> \(fd)") ; return Brand.kInvalidFont }

	#if os(iOS)
		let font = Unified.Font(descriptor: fd, size: preferredSize)
		let actualPSName = font.fontDescriptor.postscriptName
	#elseif os(macOS)
		guard let font = Unified.Font(descriptor: fd, size: preferredSize),
			  let actualPSName = font.fontDescriptor.postscriptName
		else { BKLog.error("Requested font \"\(expectPSName)\" not created. Check that spaces and order within family/face/name are correct in \(entry) -> \(fd)") ; return Brand.kInvalidFont }
	#endif

		if actualPSName != expectPSName {
			BKLog.error("Name of font is not as expected: requested \"\(expectPSName)\", got \"\(actualPSName)\". Check that spaces and order within family/face/name are correct in \(entry) -> \(fd)")
			return Brand.kInvalidFont
		}

		cache.set(payload: BrandData.FontEntry.Payload(descriptor: fd, font: font))
		return font
	}
}



// MARK: - TextAttributes
extension Brand
{
	public static let kInvalidTextAttributes: Unified.TextAttributes = [
		NSAttributedStringKey("invalid") : "invalid"
	]

	static func resolveTextAttributes(_ entry: BrandData.TextAttributesEntry, into cache: BrandData.TextAttributesEntry.Cache, using others: BrandData) -> Unified.TextAttributes
	{
		if cache.isLoaded(), let attributes = cache.payload?.attributes {
			return attributes
		}

		var payload = BrandData.TextAttributesEntry.Payload(attributes: kInvalidTextAttributes, tracking: nil)
		cache.set(payload: payload, valid: false)
		payload.attributes = Unified.TextAttributes()

		var dependencies: [BrandData.KindWithKey] = []
		var errors = false

		getBaseAttributes:
		if let name = entry.basedOn {
			guard let base = others.textAttributes[name]
			else { BKLog.error("Text attributes based on other couldn't find entry named \"\(name)\"") ; errors = true ; break getBaseAttributes }
			dependencies.append((.textAttributes, name))
			payload.attributes = base.resolved(using: others)
			payload.tracking = base._cache.payload?.tracking
			guard base.cacheIsValid()
			else { BKLog.error("Text attributes based on \"\(name)\" which are not valid") ; errors = true ; break getBaseAttributes }
		}

		parseAttributes:
		if let a = entry.attributes {
			guard case .dictionary(let dict) = a
			else { BKLog.error("The attributes key in a TextAttributes entry must have a dictionary as its value; cannot accept \(a)") ; errors = true ; break parseAttributes }
			for (key, value) in dict {
				switch key {
					case "font":
						guard case .string(let name) = value
						else { BKLog.error("Invalid value for \"font\" text attribute \"\(value)\"") ; errors = true ; continue }
						guard let fontEntry = others.fetchResolvedFontEntry(name, forKey: "font", ofKind: .textAttributes)
						else { errors = true ; continue }
						dependencies.append((.font, name))
						payload.attributes[.font] = fontEntry.resolved(using: others)
					case "foregroundColor":			// UIColor, default blackColor
						guard case .string(let name) = value
						else { BKLog.error("Invalid value for \"foregroundColor\" text attribute \"\(value)\"") ; errors = true ; continue }
						guard let colorEntry = others.fetchResolvedColorEntry(name, forKey: "foregroundColor", ofKind: .textAttributes)
						else { errors = true ; continue }
						dependencies.append((.color, name))
						payload.attributes[.foregroundColor] = colorEntry.resolved(using: others)
					case "backgroundColor":			// UIColor, default nil: no background
						guard case .string(let name) = value
						else { BKLog.error("Invalid value for \"backgroundColor\" text attribute \"\(value)\"") ; errors = true ; continue }
						guard let colorEntry = others.fetchResolvedColorEntry(name, forKey: "foregroundColor", ofKind: .textAttributes)
						else { errors = true ; continue }
						dependencies.append((.color, name))
						payload.attributes[.backgroundColor] = colorEntry.resolved(using: others)
					case "tracking":
						guard let (v, deps) = extractOneMetric(from: value, using: others, expecting: "text attributes tracking")
						else { errors = true ; continue }
						dependencies.append(contentsOf: deps)
						payload.tracking = v
/*	If and when needed...
					case "paragraphStyle": // NSParagraphStyle, default defaultParagraphStyle
						if case .string(let s) = value {
							payload.attributes[.paragraphStyle] = value
						}
					case "ligature": // NSNumber containing integer, default 1: default ligatures, 0: no ligatures
						if case .string(let s) = value {
							payload.attributes[.ligature] = value
						}
					case "kern": // NSNumber containing floating point value, in points; amount to modify default kerning. 0 means kerning is disabled.
						if case .string(let s) = value {
							payload.attributes[.kern] = value
						}
					case "strikethroughStyle": // NSNumber containing integer, default 0: no strikethrough
						if case .string(let s) = value {
							payload.attributes[.strikethroughStyle] = value
						}
					case "underlineStyle": // NSNumber containing integer, default 0: no underline
						if case .string(let s) = value {
							payload.attributes[.underlineStyle] = value
						}
					case "strokeColor": // UIColor, default nil: same as foreground color
						if case .string(let s) = value {
							payload.attributes[.strokeColor] = value
						}
					case "strokeWidth": // NSNumber containing floating point value, in percent of font point size, default 0: no stroke; positive for stroke alone, negative for stroke and fill (a typical value for outlined text would be 3.0)
						if case .string(let s) = value {
							payload.attributes[.strokeWidth] = value
						}
					case "shadow": // NSShadow, default nil: no shadow
						if case .string(let s) = value {
							payload.attributes[.shadow] = value
						}
					case "textEffect": // NSString, default nil: no text effect
						if case .string(let s) = value {
							payload.attributes[.textEffect] = value
						}
					case "attachment": // NSTextAttachment, default nil
						if case .string(let s) = value {
							payload.attributes[.attachment] = value
						}
					case "link": // NSURL (preferred) or NSString
						if case .string(let s) = value {
							payload.attributes[.link] = value
						}
					case "baselineOffset": // NSNumber containing floating point value, in points; offset from baseline, default 0
						if case .string(let s) = value {
							payload.attributes[.baselineOffset] = value
						}
					case "underlineColor": // UIColor, default nil: same as foreground color
						if case .string(let s) = value {
							payload.attributes[.underlineColor] = value
						}
					case "strikethroughColor": // UIColor, default nil: same as foreground color
						if case .string(let s) = value {
							payload.attributes[.strikethroughColor] = value
						}
					case "obliqueness": // NSNumber containing floating point value; skew to be applied to glyphs, default 0: no skew
						if case .string(let s) = value {
							payload.attributes[.obliqueness] = value
						}
					case "expansion": // NSNumber containing floating point value; log of expansion factor to be applied to glyphs, default 0: no expansion
						if case .string(let s) = value {
							payload.attributes[.expansion] = value
						}
					case "writingDirection": // NSArray of NSNumbers representing the nested levels of writing direction overrides as defined by Unicode LRE, RLE, LRO, and RLO characters.  The control characters can be obtained by masking NSWritingDirection and NSWritingDirectionFormatType values.  LRE: NSWritingDirectionLeftToRight|NSWritingDirectionEmbedding, RLE: NSWritingDirectionRightToLeft|NSWritingDirectionEmbedding, LRO: NSWritingDirectionLeftToRight|NSWritingDirectionOverride, RLO: NSWritingDirectionRightToLeft|NSWritingDirectionOverride,
						if case .string(let s) = value {
							payload.attributes[.writingDirection] = value
						}
					case "verticalGlyphForm": // An NSNumber containing an integer value.  0 means horizontal text.  1 indicates vertical text.  If not specified, it could follow higher-level vertical orientation settings.  Currently on iOS, it's always horizontal.  The behavior for any other value is undefined.
						if case .string(let s) = value {
							payload.attributes[.verticalGlyphForm] = value
						}
*/
					case "paragraphStyle", "ligature", "kern", "strikethroughStyle", "underlineStyle", "strokeColor", "strokeWidth", "shadow", "textEffect", "attachment", "link", "baselineOffset", "underlineColor", "strikethroughColor", "obliqueness", "expansion", "writingDirection", "verticalGlyphForm":
						BKLog.error("Text attribute \"\(key)\" not yet supported")
						errors = true ; continue
					default:
						BKLog.error("Unrecognised text attribute \"\(key)\"=\"\(value.asObject)\"")
						errors = true ; continue
				}
			}
		}

		enactTracking:
		if let track = payload.tracking, let font = payload.attributes[.font] as? Unified.Font {
			guard track >= -1000, track <= 5000
			else { BKLog.error("Out of range tracking value \"\(track)\"; should be >= -1000, <= 5000 ") ; errors = true ; break enactTracking }
			let size = font.pointSize
			let kern = size / CGFloat(1000) * track
			payload.attributes[.kern] = kern
		}

		guard !errors
		else { return kInvalidTextAttributes }

		cache.set(payload: payload)
		cache.depends(on: dependencies)
		return payload.attributes
	}
}



// MARK: - Placement
extension Brand.Placement
{
	public init(rules: String? = nil, auxViews av: String? = nil, metricNames mn: String? = nil, relativeDimensions rd: [Brand.RelativeDimension]? = nil, contentMode cm: Brand.ContentMode? = nil)
	{
		self.placementRules = rules
		self.auxiliaryViews = av
		self.metricNames = mn
		self.relativeDimensions = rd
		self.contentMode = cm
	}
}



extension Brand.RelativeDimension
{
	public init(_ dimension: Brand.RelativeDimension.Dimension,
		 relation: Unified.LayoutRelation = .equal, relativeTo: String, multiplier: CGFloat = 1, constant: CGFloat = 0)
	{
		self.dimension			= dimension
		self.relation			= relation
		self.relativeTo			= relativeTo
		self.multiplier			= multiplier
		self.constant			= constant
	}
}



extension Brand.ContentMode {
	public var viewContentMode: UIViewContentMode { switch self {
		case .center:				return .center
		case .top:					return .top
		case .bottom:				return .bottom
		case .left:					return .left
		case .right:				return .right
		case .topLeft:				return .topLeft
		case .topRight:				return .topRight
		case .bottomLeft:			return .bottomLeft
		case .bottomRight:			return .bottomRight
		case .resize,
			 .scaleToFill:			return .scaleToFill
		case .resizeAspect,
			 .scaleAspectFit:		return .scaleAspectFit
		case .resizeAspectFill,
			 .scaleAspectFill:		return .scaleAspectFill
		case .exactFit:				return .scaleToFill
	} }
	public var contentsGravity: String { switch self {
		case .scaleToFill:			return "resize"
		case .scaleAspectFit:		return "resizeAspect"
		case .scaleAspectFill:		return "resizeAspectFill"
		case .exactFit:				return "resize"
		default:					return rawValue
	} }
	public var constrainContainerAspect: Bool { return self == .exactFit }
}



// MARK: - Image
extension BrandData.ImageEntry : Codable
{
	enum CodingKeys : String, CodingKey {
		case basedOn, filePath, makeBackground, alignmentInsets, contentMode, placement // omit _cache
	#if os(iOS)
		case renderMode
	#elseif os(macOS)
	#endif
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		basedOn = try container.decodeIfPresent(String.self, forKey: .basedOn)
		filePath = try container.decodeIfPresent(String.self, forKey: .filePath)
		alignmentInsets = try container.decodeIfPresent(String.self, forKey: .alignmentInsets)
		contentMode = try container.decodeIfPresent(BrandData.ContentMode.self, forKey: .contentMode)
		makeBackground = try container.decodeIfPresent(SimpleBackground.self, forKey: .makeBackground)
	#if os(iOS)
		if let rm = try container.decodeIfPresent(String.self, forKey: .renderMode) {
			switch rm {
				case "automatic":	renderMode = .automatic
				case "original", "alwaysOriginal":	renderMode = .alwaysOriginal
				case "template", "alwaysTemplate":	renderMode = .alwaysTemplate
			default:
				throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Cant reconstruct RenderMode from \"\(rm)\"."))
			}
		} else {
			renderMode = nil
		}
	#elseif os(macOS)
	#endif
		placement = try container.decodeIfPresent(String.self, forKey: .placement)
		if 1 != (basedOn == nil ? 0 : 1) + (filePath == nil ? 0 : 1) + (makeBackground == nil ? 0 : 1) {
			throw DecodingError.dataCorrupted(DecodingError.Context(codingPath: container.codingPath, debugDescription: "Must have one and only one of 'basedOn', 'filePath' and 'makeBackground' keys present."))
		}
		if let key = container.codingPath.last?.stringValue, key.contains(" ") {
			throw DecodingError.dataCorrupted(DecodingError.Context.init(codingPath: [CodingKey](container.codingPath.dropLast()), debugDescription: "The coding key \"\(key)\" containing an image entry may not contain spaces."))
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encodeIfPresent(basedOn, forKey: .basedOn)
		try container.encodeIfPresent(filePath, forKey: .filePath)
		try container.encodeIfPresent(alignmentInsets, forKey: .alignmentInsets)
		try container.encodeIfPresent(contentMode, forKey: .contentMode)
		try container.encodeIfPresent(makeBackground, forKey: .makeBackground)
	#if os(iOS)
		let rm: String?
		switch renderMode {
			case .automatic?: rm = "automatic"
			case .alwaysOriginal?: rm = "original"
			case .alwaysTemplate?: rm = "template"
			default: rm = nil
		}
		try container.encodeIfPresent(rm, forKey: .renderMode)
	#elseif os(macOS)
	#endif
		try container.encodeIfPresent(placement, forKey: .placement)
	}
}



extension Brand
{
	public static let kInvalidImage: Unified.Image = {
	#if os(iOS)
		let bounds =	CGRect(origin: .zero, size: CGSize(width: 16, height: 16))
		let format =	UIGraphicsImageRendererFormat()
		format.opaque = false
		let renderer =	UIGraphicsImageRenderer.init(bounds: bounds, format: format)
		var image = renderer.image()
			{ (context: UIGraphicsImageRendererContext) in
				let w2 = bounds.size.width/2, h2 = bounds.size.height/2
				var r = CGRect(origin: .zero, size: CGSize(width: w2, height: h2))
				context.cgContext.setFillColor(UIColor.orange.withAlphaComponent(0.5).cgColor)
				r.origin = .zero ; context.fill(r)
				r.origin = CGPoint(x: w2, y: h2) ; context.fill(r)
				context.cgContext.setFillColor(UIColor.yellow.withAlphaComponent(0.5).cgColor)
				r.origin = CGPoint(x: 0, y: h2) ; context.fill(r)
				r.origin = CGPoint(x: w2, y: 0) ; context.fill(r)
			}
		image = image.resizableImage(withCapInsets: .zero)
		return image
	#elseif os(macOS)
		return NSImage(size: NSSize(width: 16, height: 16))
	#endif
	}()

	struct SimpleBackgroundParams
	{
		var fillColor:		Unified.Color? = nil
		var strokeColor:	Unified.Color? = nil
		var lineWidth:		CGFloat = 0
		var cornerRadius:	CGFloat = 0
		var minimumWidth:	CGFloat = 0
		var minimumHeight:	CGFloat = 0
	}

	static func makeSimpleBackgroundImage(with params: SimpleBackgroundParams) -> Unified.Image {
	#if os(iOS)
		guard nil != params.fillColor || (nil != params.strokeColor && 0 < params.lineWidth)
		else { return Unified.Image() }
		let lw =		params.lineWidth
		let cr =		max(params.cornerRadius, 0)
		let fixedCaps =	max(lw, cr)
		let flexibleCentre = CGFloat(4)
		let minSide =	2 * fixedCaps + flexibleCentre
		let minSize = 	CGSize(width: max(params.minimumWidth, minSide),
							  height: max(params.minimumHeight, minSide))
		let bounds =	CGRect(origin: .zero, size: minSize)
		let format =	UIGraphicsImageRendererFormat()
		format.opaque = false
		let renderer =	UIGraphicsImageRenderer.init(bounds: bounds, format: format)
		var image = renderer.image()
			{ (rendererContext: UIGraphicsImageRendererContext) in
				let context = rendererContext.cgContext
				if let fc = params.fillColor?.cgColor {
					let r = bounds
					let path = cr > 0
							 ? CGPath(roundedRect: r, cornerWidth: cr, cornerHeight: cr, transform: nil)
							 : CGPath(rect: r, transform: nil)
					context.addPath(path)
					context.setFillColor(fc)
					context.fillPath()
				}
				if let sc = params.strokeColor?.cgColor {
					let r = bounds.insetBy(dx: lw/2, dy: lw/2)
					let path = cr > 0
							 ? CGPath(roundedRect: r, cornerWidth: cr, cornerHeight: cr, transform: nil)
							 : CGPath(rect: r, transform: nil)
					context.addPath(path)
					context.setStrokeColor(sc)
					context.setLineWidth(lw)
					context.strokePath()
				}
			}
		let capInsets = Unified.EdgeInsets(all: fixedCaps)
		image = image.resizableImage(withCapInsets: capInsets, resizingMode: .stretch)
		return image
	#elseif os(macOS)
		return NSImage(size: NSSize(width: 16, height: 16))
	#endif
	}

	static func resolveImage(_ entry: BrandData.ImageEntry, into cache: BrandData.ImageEntry.Cache, using others: BrandData) -> Unified.Image
	{
		if cache.isLoaded(), let i = cache.payload {
			return i
		}
		cache.set(payload: Brand.kInvalidImage, valid: false)

		var image = Brand.kInvalidImage

		if let name = entry.basedOn {
			guard let base = others.images[name]
			else { BKLog.error("Image based on other couldn't find entry named \"\(name)\"") ; return Brand.kInvalidImage }
			cache.depends(on: .image, withKey: name)
			image = base.resolved(using: others)
			guard base.cacheIsValid()
			else { BKLog.error("Image base, named \"\(name)\", is not valid") ; return Brand.kInvalidImage }
		} else if let fp = entry.filePath {
			guard let storage = others.context.payload?.storage
			else { BKLog.fault("Storage not provided before resolveImage(_:into:using:)") ; return Brand.kInvalidImage }
			guard let data = try? Data(contentsOf: storage.appendingPathComponent(fp))
			else { BKLog.error("Could not load image data from \"\(fp)\"") ; return Brand.kInvalidImage }
			// Default scale...
			let scale = UIScreen.main.scale
			// ...needs to a) be overridable, b) do correct thing on @3x screens, etc
			// - better to have explicit target size for image
			guard !data.isEmpty, let img = Unified.Image(data: data, scale: scale)
			else { BKLog.error("Could not create image with data from \"\(fp)\"") ; return Brand.kInvalidImage }
			image = img
		} else if let simpleBg = entry.makeBackground {
			var params = SimpleBackgroundParams()
			if let name = simpleBg.fillColor {
				guard let entry = others.fetchResolvedColorEntry(name, forKey: "fillColor", ofKind: .image)
				else { return Brand.kInvalidImage }
				cache.depends(on: .color, withKey: name)
				params.fillColor = entry.resolved(using: others)
			}
			if let name = simpleBg.strokeColor {
				guard let entry = others.fetchResolvedColorEntry(name, forKey: "strokeColor", ofKind: .image)
				else { return Brand.kInvalidImage }
				cache.depends(on: .color, withKey: name)
				params.strokeColor = entry.resolved(using: others)
			}
			if let s = simpleBg.lineWidth {
				guard let (v, deps) = extractOneMetric(from: s, using: others, expecting: "simple backgound image.lineWidth")
				else { return Brand.kInvalidImage }
				cache.depends(on: deps)
				params.lineWidth = v
			}
			if let s = simpleBg.cornerRadius {
				guard let (v, deps) = extractOneMetric(from: s, using: others, expecting: "simple backgound image.cornerRadius")
				else { return Brand.kInvalidImage }
				cache.depends(on: deps)
				params.cornerRadius = v
			}
			if let s = simpleBg.minimumWidth {
				guard let (v, deps) = extractOneMetric(from: s, using: others, expecting: "simple backgound image.minimumWidth")
				else { return Brand.kInvalidImage }
				cache.depends(on: deps)
				params.minimumWidth = v
			}
			if let s = simpleBg.minimumHeight {
				guard let (v, deps) = extractOneMetric(from: s, using: others, expecting: "simple backgound image.minimumHeight")
				else { return Brand.kInvalidImage }
				cache.depends(on: deps)
				params.minimumHeight = v
			}
			image = makeSimpleBackgroundImage(with: params)
		}
		else { BKLog.error("No source for image") ; return Brand.kInvalidImage }

		if let raw = entry.alignmentInsets {
			let s = raw.replacingOccurrences(of: " ", with: "")
			let a = s.split(separator: "/", maxSplits: 3, omittingEmptySubsequences: false).map { String($0) }
			guard
				let (values, dependees) = extractMetric(forEach: a, using: others, expecting: "reading image alignmentInsets"),
				values.count == a.count
			else { return Brand.kInvalidImage }
			cache.depends(on: dependees)
			guard let insets = Unified.EdgeInsets(fromValues: values)
			else { BKLog.error("Could not parse image.\(BrandData.ImageEntry.CodingKeys.alignmentInsets.rawValue) from \"\(raw)\" (format: \"top/left/bottom/right\")") ; return Brand.kInvalidImage }
			image = image.withAlignmentRectInsets(insets)
		}

	#if os(iOS)
		if let rm = entry.renderMode {
			image = image.withRenderingMode(rm)
		}
	#elseif os(macOS)
	#endif

		if let name = entry.placement {
			guard nil != others.placements[name]
			else { BKLog.error("Can't find placement \"\(name)\" that image depends on") ; return Brand.kInvalidImage }
		}
		// (•todo:) else use placement of base, if any. (screen out base placement by explicit replacement)

		cache.set(payload: image)
		return image
	}
}



// MARK: - ButtonStyle
public struct ButtonStateStyle {
	public let titleAttributes:	Unified.TextAttributes?
	public let titleImage:		Unified.Image?
	public let backgroundImage:	Unified.Image?
}

public struct ButtonStyle {
	public let stateStyles:		[UIControlState:ButtonStateStyle]
	public let contentInsets:	Unified.EdgeInsets?
	public let tintColor:		Unified.Color?
	public let reverseIconSide:	Bool
}

extension Brand
{
	public static let kInvalidButtonStyle = ButtonStyle(stateStyles: [:], contentInsets: nil, tintColor: nil, reverseIconSide: false)

	static func resolveButtonStyle(_ entry: BrandData.ButtonStyleEntry, into cache: BrandData.ButtonStyleEntry.Cache, using others: BrandData) -> ButtonStyle
	{
		if cache.isLoaded(), let buttonStyle = cache.payload {
			return buttonStyle
		}

		var payload = kInvalidButtonStyle
		cache.set(payload: payload, valid: false)
		var stateStyles = [UIControlState:ButtonStateStyle]()
		var contentInsets: Unified.EdgeInsets? = nil
		var tintColor: Unified.Color? = nil

		var dependencies: [(kind: BrandData.Kind, name: String)] = []
		var errors = false

		func addElements(from elementNames: BrandData.ButtonStyleEntry.StyleElementNames?, for state: UIControlState) {
			guard let names = elementNames
			else { return }

			var titleAttributes:	Unified.TextAttributes? = nil
			var titleImage:			Unified.Image? = nil
			var backgroundImage:	Unified.Image? = nil
			var values = false

			if let name = names.titleAttributes {
				if let entry = others.fetchResolvedTextAttributesEntry(name, forKey: "titleAttributes", ofKind: .buttonStyle) {
					titleAttributes = entry.resolved(using: others)
					dependencies.append((kind: .textAttributes, name: name))
					values = true
				} else {
					errors = true
				}
			}
			if let name = names.titleImage {
				if let entry = others.fetchResolvedImageEntry(name, forKey: "titleImage", ofKind: .buttonStyle) {
					titleImage = entry.resolved(using: others)
					dependencies.append((kind: .image, name: name))
					values = true
				} else {
					errors = true
				}
			}
			if let name = names.backgroundImage {
				if let entry = others.fetchResolvedImageEntry(name, forKey: "backgroundImage", ofKind: .buttonStyle) {
					backgroundImage = entry.resolved(using: others)
					dependencies.append((kind: .image, name: name))
					values = true
				} else {
					errors = true
				}
			}
			if values && !errors {
				stateStyles[state] = ButtonStateStyle(titleAttributes: titleAttributes, titleImage: titleImage, backgroundImage: backgroundImage)
			}
		}

		addElements(from: entry.normalStyle, for: .normal)
		addElements(from: entry.highlightedStyle, for: .highlighted)
		addElements(from: entry.disabledStyle, for: .disabled)
		addElements(from: entry.selectedStyle, for: .selected)

		parseContentInsets:
		if let raw = entry.contentInsets {
			let s = raw.replacingOccurrences(of: " ", with: "")
			let a = s.split(separator: "/", maxSplits: 3, omittingEmptySubsequences: false).map { String($0) }
			guard
				let (values, dependees) = extractMetric(forEach: a, using: others, expecting: "reading button style contentInsets"),
				values.count == a.count
			else { return Brand.kInvalidButtonStyle }
			cache.depends(on: dependees)
			guard let insets = Unified.EdgeInsets(fromValues: values)
			else { BKLog.error("Could not parse buttonStyle contentInsets from \"\(raw)\" (format: \"top/left/bottom/right\")") ; errors = true ; break parseContentInsets }
			contentInsets = insets
		}

		parseTintColor:
		if let name = entry.tintColor {
			guard let entry = others.fetchResolvedColorEntry(name, forKey: name, ofKind: .buttonStyle)
			else { return Brand.kInvalidButtonStyle }
			cache.depends(on: .color, withKey: name)
			tintColor = entry.resolved(using: others)
		}

		let reverseIconSide = entry.reverseIconSide ?? false

		guard !errors
		else { return kInvalidButtonStyle }

		payload = ButtonStyle(stateStyles: stateStyles, contentInsets: contentInsets, tintColor: tintColor, reverseIconSide: reverseIconSide)
		cache.set(payload: payload)
		dependencies.forEach { cache.depends(on: $0, withKey: $1) }
		return payload
	}
}



// MARK: -
extension Unified.LayoutRelation : Codable
{
	public init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		let raw = try container.decode(String.self)
		switch raw {
			case "<=", "LE", "le", "lessThanOrEqual":
				self = .lessThanOrEqual
			case "==", "EQ", "eq", "equal":
				self = .equal
			case ">=", "GE", "ge", "greaterThanOrEqual":
				self = .greaterThanOrEqual
			default:
				throw DecodingError.dataCorruptedError(in: container, debugDescription: "No LayoutRelation recognised from value \"\(raw)\"")
		}
	}

	public func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		switch self {
			case .lessThanOrEqual:		try container.encode("lessThanOrEqual")
			case .equal:				try container.encode("equal")
			case .greaterThanOrEqual:	try container.encode("greaterThanOrEqual")
		}
	}
}



extension UIControlState : Hashable {
	public var hashValue: Int {
		return rawValue.hashValue
	}
}



// MARK: - CustomParameters
extension Brand
{
	public static let kInvalidCustomParameter = NSObject()
}



extension BrandData.CustomParametersEntry : Codable
{
	init(from decoder: Decoder) throws {
		let container = try decoder.singleValueContainer()
		raw = try container.decode(AnyJSONObject.self)
		if let key = container.codingPath.last?.stringValue, key.contains(" "), raw.isNotNull {
			throw DecodingError.dataCorruptedError(in: container, debugDescription: "The coding key \"\(key)\" containing this custom parameter entry may not contain spaces.")
		}
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.singleValueContainer()
		try container.encode(raw)
	}
}



extension BrandData.CustomParametersEntry
{
	func string(at keyPath: String, using brand: Brand) -> String? {
		guard let obj = raw.value(at: keyPath)
		else { return nil }
		return obj.asString
	}

	func int(at keyPath: String, using brand: Brand) -> Int? {
		let expect = "acessing parameter \"\(keyPath)\""
		guard
			let data = brand.data,
			let obj = raw.value(at: keyPath),
			let (value, _) = Brand.extractOneMetric(from: obj, using: data, expecting: expect)
		else { return nil }
		return Int(value)
	}

	func float(at keyPath: String, using brand: Brand) -> CGFloat? {
		let expect = "acessing parameter \"\(keyPath)\""
		guard
			let data = brand.data,
			let obj = raw.value(at: keyPath),
			let (value, _) = Brand.extractOneMetric(from: obj, using: data, expecting: expect)
		else { return nil }
		return value
	}

	func floatArray(at keyPath: String, using brand: Brand) -> [CGFloat]? {
		let expect = "acessing parameter \"\(keyPath)\""
		guard
			let data = brand.data,
			let obj = raw.value(at: keyPath),
			let (values, _) = Brand.extractMetrics(from: obj, using: data, expecting: expect)
		else { return nil }
		return values
	}

	func point(at keyPath: String, using brand: Brand) -> CGPoint? {
		let expect = "acessing parameter \"\(keyPath)\""
		guard
			let data = brand.data,
			let obj = raw.value(at: keyPath),
			let (values, _) = Brand.extractMetrics(count: 2, from: obj, using: data, expecting: expect)
		else { return nil }
		return CGPoint(x: values[0], y: values[1])
	}

	func size(at keyPath: String, using brand: Brand) -> CGSize? {
		let expect = "acessing parameter \"\(keyPath)\""
		guard
			let data = brand.data,
			let obj = raw.value(at: keyPath),
			let (values, _) = Brand.extractMetrics(count: 2, from: obj, using: data, expecting: expect)
		else { return nil }
		return CGSize(width: values[0], height: values[1])
	}

	func insets(at keyPath: String, using brand: Brand) -> UIEdgeInsets? {
		let expect = "acessing parameter \"\(keyPath)\""
		guard
			let data = brand.data,
			let obj = raw.value(at: keyPath),
			let (values, _) = Brand.extractMetrics(count: 4, from: obj, using: data, expecting: expect)
		else { return nil }
		return UIEdgeInsets(top: values[0], left: values[1], bottom: values[2], right: values[3])
	}

	func color(at keyPath: String, using brand: Brand) -> UIColor? {
		guard
			let data = brand.data,
			case .string(let name)? = raw.value(at: keyPath),
			let entry = data.fetchResolvedColorEntry(name, forKey: keyPath, ofKind: .customParameters)
		else { return nil }
		let color = entry.resolved(using: data)
		return color
	}
}
