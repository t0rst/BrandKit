/*
	TestBrand.swift
	BrandKit

	Created by Torsten Louland on 21/01/2018.

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

import XCTest
@testable import BrandKit
import T0Utils
class Unified : T0Unified {}



class TestBrand : XCTestCase {
	
	override func setUp() { super.setUp() /**/ }
	override func tearDown() { /**/ super.tearDown() }

	func assembleBrandDataJSON(colors: String = "", metrics: String = "", fonts: String = "", textAttributes: String = "", placements: String = "", images: String = "") -> Data {
		let combined =
			"""
			{
			"version":1,
			"colors":{
				\(colors)},
			"metrics":{
				\(metrics)},
			"fonts":{
				\(fonts)},
			"textAttributes":{
				\(textAttributes)},
			"placements":{
				\(placements)},
			"images":{
				\(images)}
			}
			"""
		let data = combined.data(using: .utf8)
		return data ?? Data()
	}

	func test00_LoadColors() {
		let data = assembleBrandDataJSON(
		colors:
			"""
			"red1":"rgb/255/0/0",
			"red2":"rgb/1/0/0",
			"red3":"rgb/1//",
			"red4":"rgba/255/0/0/255",
			"red5":"rgba/1/0/0/1",
			"red6":"rgba/1.0//.0/01.0",
			"red7":"rgba/1.0///",
			"red8":"named/red7",
			"red9":"named/red",
			"red10":" n a m e d / r e d",
			"white1":"w/255",
			"white2":"w/1",
			"white3":"w/1.0",
			"white4":"wa/255/255",
			"white5":"wa/255/",
			"white6":"wa/1.0/1",
			"white7":"wa/1/",
			"red11":"hsb/0/255/255",
			"red12":"hsb/0/1/1",
			"red13":"hsb//1/1",
			"red14":"hsba/0/255/255/255",
			"red15":"hsba/0/1/1/1",
			"red16":"hsba//1.0/01/01.0",
			"red17":"web/FF0000",
			"red18":"web/ff0000"
			"""
		)
		let brandData: BrandData
		do {
			brandData = try JSONDecoder().decode(BrandData.self, from: data)
		} catch {
			XCTFail("JSONDecoder().decode(BrandData.self, from: data) threw \(error)")
			return
		}

		let deviceRed = Unified.Color(red: 1, green: 0, blue: 0, alpha: 1)
		let deviceWhite = Unified.Color(white: 1, alpha: 1)

		for (baseName, range, expectedColor) in [
			("red", 1...8, deviceRed),
			("red", 9...10, Unified.Color.red),
			("red", 11...18, deviceRed),
			("white", 1...7, deviceWhite)
		] {
			for i in range {
				let name = "\(baseName)\(i)"
				guard let entry = brandData.colors[name]
				else { XCTFail("Can't find brandData.colors[\(name)]") ; continue }
				let color = entry.resolved(using: brandData)
				if !color.cgColor.__equalTo(expectedColor.cgColor) {
					XCTFail("\nbrandData.colors[\(name)] is not \(baseName):\ncolor=\(color)\nexpected=\(expectedColor)")
				}
			}
		}
	}

	func test01_FailBadColors() {
		let data = assembleBrandDataJSON(colors:
			"""
			"red1":"zrgb/255/0/0",
			"red2":"rgb/1/0",
			"red3":"rgb/1/a/",
			"red4":"rgba/255/0/0/2550/255",
			"red5":"rgba/1/0.1/255/1",
			"red6":"rgba/1,0//.0/01.0",
			"red7":"rgba/////",
			"red8":"named/red1",
			"red9":"named/rod",
			"red10":" N a m e d / r e d",
			"white1":"w",
			"white2":"w///1",
			"white3":"w/1,0",
			"white4":"wa/355/255",
			"white5":"wa/f0/dd",
			"white6":"wa/.999999999999999/.7/.6/1",
			"white7":"wa/1",
			"red11":"hsb/0/255",
			"red12":"hsb/0/1/1/0",
			"red13":"hsb/-/1/1",
			"red14":"hsba/0/255/255/255/-1",
			"red15":"hsba/0/1/1",
			"red16":"hsba//1.0/01/0,1,0",
			"red17":"web/FF000",
			"red18":"web/fg0000",
			"red19":"web/ff00ccAA00"
			"""
		)
		let brandData: BrandData
		do {
			brandData = try JSONDecoder().decode(BrandData.self, from: data)
		} catch {
			XCTFail("JSONDecoder().decode(BrandData.self, from: data) threw \(error)")
			return
		}

		for (baseName, range, expectedColor) in [
			("red", 1...19, Brand.kInvalidColor),
			("white", 1...7, Brand.kInvalidColor)
		] {
			for i in range {
				let name = "\(baseName)\(i)"
				guard let entry = brandData.colors[name]
				else { XCTFail("Can't find brandData.colors[\(name)]") ; continue }
				let color = entry.resolved(using: brandData)
				if !color.cgColor.__equalTo(expectedColor.cgColor) {
					XCTFail("\nbrandData.colors[\(name)] should not be \(baseName):\ncolor=\(color)\nexpected=\(expectedColor)")
				}
			}
		}

		let badData = assembleBrandDataJSON(colors:
			"""
			"no spaces allowed":"w/1"
			"""
		)
		XCTAssertThrowsError(try JSONDecoder().decode(BrandData.self, from: badData), "Should have trapped spaces in color key")
	}

	func test02_LoadMetrics() {
		let data = assembleBrandDataJSON(metrics:
			"""
			"valid1":"0 0 0",
			"valid2":"0x000",
			"valid3":"1",
			"valid4":"named/valid3",
			"invalid1":"FF",
			"invalid2":"named/",
			"invalid3":"named/zzzz",
			"invalid4":"named/0.1",
			"invalid5":"/zzzz",
			"""
		)
		let brandData: BrandData
		do {
			brandData = try JSONDecoder().decode(BrandData.self, from: data)
		} catch {
			XCTFail("JSONDecoder().decode(BrandData.self, from: data) threw \(error)")
			return
		}

		for (baseName, range, expected) in [
			("valid", 1...2, CGFloat(0)),
			("valid", 3...4, CGFloat(1)),
			("invalid", 1...5, Brand.kInvalidMetric)
		] {
			for i in range {
				let name = "\(baseName)\(i)"
				guard let entry = brandData.metrics[name]
				else { XCTFail("Can't find brandData.metrics[\(name)]") ; continue }
				let value = entry.resolved(using: brandData)
				if !(value.isNaN && expected.isNaN) && (value != expected) {
					XCTFail("\nbrandData.metrics[\(name)] is not as expected:\nvalue=\(value)\nexpected=\(expected)")
				}
			}
		}
	}

	func test03_LoadFonts() {
		let data = assembleBrandDataJSON(
		metrics:
			"""
			"size_heading":"45",
			"size_caption":"17",
			"size_body":"14",
			""",
		fonts:
			"""
			"base":{"family":"Avenir Next"},
			"head":{"basedOn":"base","face":"Ultra Light","size":"size_heading"},
			"caption":{"basedOn":"base","face":"Medium","size":"size_caption"},
			"body":{"basedOn":"base","size":"size_body","attributes":{"family":"Baskerville","face":"Italic"}},
			"""
		)
		let brandData: BrandData
		do {
			brandData = try JSONDecoder().decode(BrandData.self, from: data)
		} catch {
			XCTFail("JSONDecoder().decode(BrandData.self, from: data) threw \(error)")
			return
		}

		for (name, expect) in [
			("base", "AvenirNext-Regular:17.0"),
			("head", "AvenirNext-UltraLight:45.0"),
			("caption", "AvenirNext-Medium:17.0"),
			("body", "Baskerville-Italic:14.0")
		] {
			guard let entry = brandData.fonts[name]
			else { XCTFail("Can't find brandData.fonts[\(name)]") ; continue }
			let font = entry.resolved(using: brandData)
			let actual = "\(font.fontName):\(font.pointSize)"
			XCTAssertTrue(actual == expect, "\nfont entry \"\(name)\":\nactual=\(actual)\nexpect=\(expect)")
		}
	}

	func test04_FailBadFonts() {
		let data = assembleBrandDataJSON(
		metrics:
			"""
			"size_body":"14",
			"size_bad":"aaaa",
			""",
		fonts:
			"""
			"bad2":{"family":"AvenirNext"},
			"bad3":{"basedOn":"bad"},
			"bad4":{"basedOn":"bad2"},
			"bad4":{"basedOn":"bad2"},
			"bad5":{"basedOn":"base","face":"Ultra Light","size":"size_heading"},
			"bad6":{"attributes":{"familie":"Baskerville","fice":"Italic"}},
			"bad7":{"size":"size_badly","attributes":{"family":"Baskerville","face":"Italic"}},
			"bad8":{"size":"size_bad","attributes":{"family":"Baskerville","face":"Italic"}},
			"""
		//	"bad1":{"familie":"Avenir Next"},
		//	...to be fixed - mis-spelt keys not detected/warned
		//	"bad9":{"size":"size_body","attributes":{"family":["Baskerville"],"face":["Italic"]}},
		//	...to be fixed - incompatible types not rejected as they should be
		)
		let brandData: BrandData
		do {
			brandData = try JSONDecoder().decode(BrandData.self, from: data)
		} catch {
			XCTFail("JSONDecoder().decode(BrandData.self, from: data) threw \(error)")
			return
		}

		for (baseName, range, expectFont) in [
			("bad", 2...8, Brand.kInvalidFont)
		] {
			let expect = "\(expectFont.fontName):\(expectFont.pointSize)"
			for i in range {
				let name = "\(baseName)\(i)"
				guard let entry = brandData.fonts[name]
				else { XCTFail("Can't find brandData.fonts[\(name)]") ; continue }
				let font = entry.resolved(using: brandData)
				let actual = "\(font.fontName):\(font.pointSize)"
				XCTAssertTrue(actual == expect, "\nfont entry \"\(name)\":\nactual=\(actual)\nexpect=\(expect)")
			}
		}
	}

	func test05_LoadImages() {
	#if os(iOS)
		let renderModeTestData =
			"""
			"image1":{"basedOn":"image0", "renderMode":"template"},
			"image2":{"basedOn":"image0", "renderMode":"original"},
			"image3":{"basedOn":"image0", "renderMode":"automatic"},
			"""
	#elseif os(macOS)
		let renderModeTestData = ""
	#endif
		let data = assembleBrandDataJSON(
		metrics:
			"""
			"size_body":"14",
			""",
		placements:
			"""
			"logo_banner":{
				"relativeDimensions":[
					{"dimension":"width","relation":"eq","relativeTo":"super","multiplier":0.3,"constant":0}
				]
			},
			""",
		images:
			"""
			"image0":{"filePath":"TestImage_1024.png"},
			\(renderModeTestData)
			"image4":{"basedOn":"image0", "insetAlignmentBy_tlbr":"64/96/54/106"},
			"image5":{"basedOn":"image0", "insetAlignmentBy_tlbr":" 20//20/"},
			"image6":{"basedOn":"image0", "insetAlignmentBy_tlbr":" 2.0/0x7f/20/ "},
			"image7":{"filePath":"TestImage_1024.png", "placement":"logo_banner"},
			"""
		)
		let brandData: BrandData
		do {
			brandData = try JSONDecoder().decode(BrandData.self, from: data)
		} catch {
			XCTFail("JSONDecoder().decode(BrandData.self, from: data) threw \(error)")
			return
		}

		// Add storage pointing to location of test images
		let bundle = Bundle(for: TestBrand.self)
		guard let url = bundle.url(forResource: "TestImage", withExtension: "empty")
		else { XCTFail("Can't locate test images") ; return }
		let storage = url.deletingLastPathComponent()
		brandData.context.set(payload: BrandData.Context(storage: storage))

		typealias ImageTest = (Unified.Image)->Bool
		var tests = Array<(String, String, ImageTest)>(arrayLiteral:
			("image4", "insetAlignBy==64/96/54/106", { $0.alignmentRectInsets == Unified.EdgeInsets(t:64,l:96,b:54,r:106) } ),
			("image5", "insetAlignBy==20/0/20/0", { $0.alignmentRectInsets == Unified.EdgeInsets(t:20,l:0,b:20,r:0) } ),
			("image6", "insetAlignBy==2.0/0x7f/20/0", { $0.alignmentRectInsets == Unified.EdgeInsets(t:2,l:127,b:20,r:0) } ),
			("image0", "valid image", { $0 !== Brand.kInvalidImage } ),
			("image7", "valid image", { $0 !== Brand.kInvalidImage } )
		)
	#if os(iOS)
		tests.append(contentsOf: Array<(String, String, ImageTest)>(arrayLiteral:
			("image1", "renderMode==template", { $0.renderingMode == .alwaysTemplate } ),
			("image2", "renderMode==original", { $0.renderingMode == .alwaysOriginal } ),
			("image3", "renderMode==automatic", { $0.renderingMode == .automatic } )
		))
	#elseif os(macOS)
		tests.append(contentsOf: [])
	#endif
		for (name, desc, test) in tests {
			guard let entry = brandData.images[name]
			else { XCTFail("Can't find brandData.images[\(name)]") ; continue }
			let image = entry.resolved(using: brandData)
			XCTAssertTrue(test(image), "Expected \(desc)")
		}
	}

	func test06_FailBadImages() {
	#if os(iOS)
		let renderModeTestData =
			"""
			"image3":{"basedOn":"image1", "renderMode":"template"},
			"image4":{"basedOn":"image3", "renderMode":"original"},
			"""
	#elseif os(macOS)
		let renderModeTestData = ""
	#endif
		var data = assembleBrandDataJSON(
		images:
			"""
			"image1":{"filePath":"TestImage_512"},
			"image2":{"filePath":"TestImage.empty"},
			"image5":{"filePath":"TestImage_1024.png", "insetAlignmentBy_tlbr":"64,96,54,106"},
			"image6":{"filePath":"TestImage_1024.png", "insetAlignmentBy_tlbr":"64,0///"},
			"image7":{"filePath":"TestImage_1024.png", "placement":"wrong"},
			\(renderModeTestData)
			"""
		)
		let brandData: BrandData
		do {
			brandData = try JSONDecoder().decode(BrandData.self, from: data)
		} catch {
			XCTFail("JSONDecoder().decode(BrandData.self, from: data) threw \(error)")
			return
		}


		// Add storage pointing to location of test images
		let bundle = Bundle(for: TestBrand.self)
		guard let url = bundle.url(forResource: "TestImage", withExtension: "empty")
		else { XCTFail("Can't locate test images") ; return }
		let storage = url.deletingLastPathComponent()
		brandData.context.set(payload: BrandData.Context(storage: storage))

		typealias ImageTest = (Unified.Image)->Bool
		var tests = [("image", 1...2), ("image", 5...7)]
	#if os(iOS)
		tests.append(("image", 3...4))
	#elseif os(macOS)
		tests.append(contentsOf: [])
	#endif
		for (baseName, range) in tests
		{
			for i in range {
				let name = "\(baseName)\(i)"
				guard let entry = brandData.images[name]
				else { XCTFail("Can't find brandData.images[\(name)]") ; continue }
				let image = entry.resolved(using: brandData)
				XCTAssertTrue(image === Brand.kInvalidImage, "Expected \(name) to be invalid")
			}
		}
		data = assembleBrandDataJSON(images:
			"""
			"image":{}
			""")
		XCTAssertThrowsError(try JSONDecoder().decode(BrandData.self, from: data))
		data = assembleBrandDataJSON(images:
			"""
			"image":{"basedOn":"a","filePath":"b"}
			""")
		XCTAssertThrowsError(try JSONDecoder().decode(BrandData.self, from: data))
	#if os(iOS)
		data = assembleBrandDataJSON(images:
			"""
			"image":{"renderMode":"auto"}
			""")
		XCTAssertThrowsError(try JSONDecoder().decode(BrandData.self, from: data))
	#elseif os(macOS)
	#endif
	}

	func test07_LoadTextAttributes() {
		let data = assembleBrandDataJSON(
		colors:
			"""
			"red1":"rgb/255/0/0",
			"red7":"rgba/1.0///",
			"red8":"named/red7",
			"red9":"named/red8",
			"theme":" n a m e d / r e d 9",
			"theme_light":"named/white"
			""",
		metrics:
			"""
			"size_heading":"45",
			"size_caption":"17",
			"size_body":"14",
			""",
		fonts:
			"""
			"base":{"family":"Avenir Next"},
			"head":{"basedOn":"base","face":"Ultra Light","size":"size_heading"},
			"caption":{"basedOn":"base","face":"Medium","size":"size_caption"},
			"body":{"basedOn":"base","size":"size_body","attributes":{"family":"Baskerville","face":"Italic"}},
			""",
		textAttributes:
			"""
			"body":{"attributes":{"font":"body","foregroundColor":"theme"}},
			"caption":{"basedOn":"body","attributes":{"font":"caption","tracking":400}},
			"""
		)
		let brandData: BrandData
		do {
			brandData = try JSONDecoder().decode(BrandData.self, from: data)
		} catch {
			XCTFail("JSONDecoder().decode(BrandData.self, from: data) threw \(error)")
			return
		}

		let deviceRed = Unified.Color(red: 1, green: 0, blue: 0, alpha: 1)

		typealias T = Unified.TextAttributes
		typealias Test = (T)->Bool
		let tests = Array<(String, String, Test)>(arrayLiteral:
			("body", "body font",
				{ (t:T)->Bool in return (t[.font] as? Unified.Font)?.fontDescriptor.postscriptName == "Baskerville-Italic" }
			),
			("body", "foreground color red",
				{ (t:T)->Bool in return (t[.foregroundColor] as? Unified.Color)?.cgColor.__equalTo(deviceRed.cgColor) ?? false }
			),
			("caption", "caption font",
				{ (t:T)->Bool in return (t[.font] as? Unified.Font)?.fontDescriptor.postscriptName == "AvenirNext-Medium" }
			),
			("caption", "foreground color red",
				{ (t:T)->Bool in return (t[.foregroundColor] as? Unified.Color)?.cgColor.__equalTo(deviceRed.cgColor) ?? false }
			),
			("caption", "foreground color red",
				{ (t:T)->Bool in return ((t[.kern] as? CGFloat) ?? CGFloat(0)) == CGFloat(17) / CGFloat(1000) * CGFloat(400) }
			)
		)
		for (name, desc, test) in tests {
			guard let entry = brandData.textAttributes[name]
			else { XCTFail("Can't find brandData.textAttributes[\(name)]") ; continue }
			let textAttributes = entry.resolved(using: brandData)
			XCTAssertTrue(test(textAttributes), "Expected \(desc)")
		}
	}

}
