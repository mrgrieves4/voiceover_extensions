// ax_table_position
//
// Hit-tests the accessibility tree at a given screen point (the VoiceOver
// cursor's position, passed in by the calling AppleScript) and looks for
// a row/column index on the hit element or its ancestors.
//
// This exists because extracting an AXValue-wrapped CFRange (what
// AXRowIndexRange/AXColumnIndexRange return) from plain AppleScriptObjC is
// unreliable - ASObjC can't marshal a raw AXUIElementRef between two
// Accessibility API calls at all, and even where it can call a single
// function, unpacking the CFRange struct out of the result isn't
// supported cleanly. Swift has proper access to both, so this small tool
// does the actual work and the AppleScript just shells out to it.
//
// Usage: ax_table_position <x> <y>
// Prints one of:
//   OK <row> <col>          - 0-based row/column indices found
//   NONE                    - no element at that point
//   UNRESOLVED <role trail> | <attribute names on the hit element>
//   ERROR <message>

import Foundation
import ApplicationServices

func getAttribute(_ element: AXUIElement, _ attr: String) -> AnyObject? {
	var value: AnyObject?
	let err = AXUIElementCopyAttributeValue(element, attr as CFString, &value)
	return err == .success ? value : nil
}

func getParent(_ element: AXUIElement) -> AXUIElement? {
	guard let value = getAttribute(element, kAXParentAttribute as String) else { return nil }
	return (value as! AXUIElement)
}

func getRangeStart(_ element: AXUIElement, _ attr: String) -> Int? {
	guard let value = getAttribute(element, attr) else { return nil }
	let axValue = value as! AXValue
	var range = CFRange(location: 0, length: 0)
	if AXValueGetValue(axValue, .cfRange, &range) {
		return range.location
	}
	return nil
}

func attributeNames(_ element: AXUIElement) -> [String] {
	var names: CFArray?
	let err = AXUIElementCopyAttributeNames(element, &names)
	if err == .success, let arr = names as? [String] {
		return arr
	}
	return []
}

func roleOf(_ element: AXUIElement) -> String {
	return (getAttribute(element, kAXRoleAttribute as String) as? String) ?? "?"
}

let args = CommandLine.arguments
guard args.count >= 3, let x = Double(args[1]), let y = Double(args[2]) else {
	print("ERROR usage: ax_table_position <x> <y>")
	exit(1)
}

let systemWide = AXUIElementCreateSystemWide()
var hitElement: AXUIElement?
let hitErr = AXUIElementCopyElementAtPosition(systemWide, Float(x), Float(y), &hitElement)

guard hitErr == .success, let startElement = hitElement else {
	print("NONE (hit-test error code \(hitErr.rawValue))")
	exit(0)
}

var rowIndex: Int?
var colIndex: Int?
var current: AXUIElement? = startElement
var hops = 0
var roleTrail: [String] = []

while let element = current, hops < 8 {
	roleTrail.append(roleOf(element))

	if rowIndex == nil {
		rowIndex = getRangeStart(element, "AXRowIndexRange")
	}
	if colIndex == nil {
		colIndex = getRangeStart(element, "AXColumnIndexRange")
	}
	if rowIndex != nil && colIndex != nil {
		break
	}

	current = getParent(element)
	hops += 1
}

if let r = rowIndex, let c = colIndex {
	print("OK \(r) \(c)")
} else {
	let names = attributeNames(startElement)
	print("UNRESOLVED \(roleTrail.joined(separator: ">")) | \(names.joined(separator: ","))")
}
