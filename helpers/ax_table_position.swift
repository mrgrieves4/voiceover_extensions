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
// Apps with custom-drawn tables (Numbers, and likely Pages/Keynote) hit-test
// to an AXHandle - a resize-handle overlay drawn on top of the selected
// cell - whose ancestors go AXHandle -> AXTable -> ... , skipping right
// past the actual AXRow/AXCell elements (children of AXTable, not
// ancestors of the handle). When the ancestor walk comes up empty but
// passes through an AXTable, this falls back to searching that table's
// AXVisibleCells for the cell whose AXFrame contains the hit point, then
// (if that also fails) to the table's AXSelectedCells.
//
// With a mode argument of row-header or column-header, it instead prints
// the text of the header for the cell's row or column:
//   column-header: the cell's AXColumnHeaderUIElements (web tables), else
//     the AXHeader of the table's matching AXColumn (AppKit/SwiftUI tables,
//     whose header row isn't a real row), else the table's own
//     AXColumnHeaderUIElements, else - for tables whose top row holds the
//     labels without being marked up as a header - the top cell in the column.
//   row-header: the cell's or table's AXRowHeaderUIElements, else the first
//     cell in the row with any text, trying only the first two (so a leading
//     tickbox column is skipped over).
// Cells are looked up via the table's AXCellForColumnAndRow where
// supported, otherwise by scanning the table's rows/cells for the one whose
// row/column index ranges cover the wanted position.
//
// Usage: ax_table_position <x> <y> [row-header|column-header]
// Prints one of:
//   OK <row> <col>          - 0-based row/column indices found (no mode)
//   TEXT <text>             - the header text (with a mode; empty if the
//                             header/fallback cells are blank)
//   NOCELL <row> <col> <role trail> - position found, but no header or fallback cell
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

func getRange(_ element: AXUIElement, _ attr: String) -> CFRange? {
	guard let value = getAttribute(element, attr) else { return nil }
	let axValue = value as! AXValue
	var range = CFRange(location: 0, length: 0)
	if AXValueGetValue(axValue, .cfRange, &range) {
		return range
	}
	return nil
}

func getRangeStart(_ element: AXUIElement, _ attr: String) -> Int? {
	return getRange(element, attr)?.location
}

func rangeCovers(_ element: AXUIElement, _ attr: String, _ index: Int) -> Bool {
	guard let range = getRange(element, attr) else { return false }
	return index >= range.location && index < range.location + max(range.length, 1)
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

func frameOf(_ element: AXUIElement) -> CGRect? {
	guard let value = getAttribute(element, "AXFrame") else { return nil }
	let axValue = value as! AXValue
	var rect = CGRect.zero
	if AXValueGetValue(axValue, .cgRect, &rect) {
		return rect
	}
	return nil
}

// Finds the cell at (x, y) among a table's AXVisibleCells, then falls back
// to its AXSelectedCells if there's exactly one (e.g. when the point landed
// exactly on an overlay handle whose own frame doesn't line up with any
// cell's frame).
func findCell(inTable table: AXUIElement, atX x: Double, y: Double) -> AXUIElement? {
	let point = CGPoint(x: x, y: y)
	if let cells = getAttribute(table, "AXVisibleCells") as? [AXUIElement] {
		for cell in cells {
			if let frame = frameOf(cell), frame.contains(point) {
				return cell
			}
		}
	}
	if let selected = getAttribute(table, "AXSelectedCells") as? [AXUIElement], selected.count == 1 {
		return selected[0]
	}
	return nil
}

func isCell(_ element: AXUIElement, row: Int, column: Int) -> Bool {
	return rangeCovers(element, "AXRowIndexRange", row) && rangeCovers(element, "AXColumnIndexRange", column)
}

// Finds the cell at (row, column) in a table: first via the table's own
// AXCellForColumnAndRow (Numbers, web tables), then by scanning its
// AXVisibleCells and each AXRows row's children for a cell whose index
// ranges cover that position.
func findCell(inTable table: AXUIElement, row: Int, column: Int) -> AXUIElement? {
	var cellValue: AnyObject?
	let params = [column, row] as CFArray
	if AXUIElementCopyParameterizedAttributeValue(table, "AXCellForColumnAndRow" as CFString, params, &cellValue) == .success,
	   let value = cellValue, CFGetTypeID(value) == AXUIElementGetTypeID() {
		return (value as! AXUIElement)
	}
	if let cells = getAttribute(table, "AXVisibleCells") as? [AXUIElement] {
		for cell in cells where isCell(cell, row: row, column: column) {
			return cell
		}
	}
	if let rows = getAttribute(table, kAXRowsAttribute as String) as? [AXUIElement] {
		for rowElement in rows {
			let children = (getAttribute(rowElement, kAXChildrenAttribute as String) as? [AXUIElement]) ?? []
			for cell in children where isCell(cell, row: row, column: column) {
				return cell
			}
		}
	}
	return nil
}

// Collects the readable text of an element: its own value/title/description
// if it has one, otherwise its descendants' text joined with spaces (cells
// usually wrap their text in an AXStaticText or similar child).
// Checkboxes and radio buttons are skipped entirely: their value is just
// 0/1, which isn't useful as a label (e.g. a tickbox column in a table).
func textOf(_ element: AXUIElement, depth: Int = 0) -> String {
	let role = roleOf(element)
	if role == "AXCheckBox" || role == "AXRadioButton" {
		return ""
	}
	for attr in [kAXValueAttribute, kAXTitleAttribute, kAXDescriptionAttribute] {
		if let value = getAttribute(element, attr as String) {
			let text: String
			if let str = value as? String {
				text = str
			} else if let num = value as? NSNumber {
				text = num.stringValue
			} else {
				continue
			}
			let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
			if !trimmed.isEmpty {
				return trimmed
			}
		}
	}
	guard depth < 6, let children = getAttribute(element, kAXChildrenAttribute as String) as? [AXUIElement] else {
		return ""
	}
	return children.map { textOf($0, depth: depth + 1) }.filter { !$0.isEmpty }.joined(separator: " ")
}

func singleLine(_ text: String) -> String {
	return text.components(separatedBy: .newlines).joined(separator: " ")
}

// Returns the text of the first header element in `attr` (an array of
// header elements on the given element) that has any. Where the elements
// carry an index range (`rangeAttr`), only those covering `index` count.
func headerText(_ element: AXUIElement, _ attr: String, _ rangeAttr: String, _ index: Int) -> String? {
	guard let headers = getAttribute(element, attr) as? [AXUIElement] else { return nil }
	for header in headers {
		if getRange(header, rangeAttr) != nil && !rangeCovers(header, rangeAttr, index) {
			continue
		}
		let text = textOf(header)
		if !text.isEmpty {
			return text
		}
	}
	return nil
}

func columnHeaderText(table: AXUIElement?, cell: AXUIElement?, column: Int) -> String? {
	if let c = cell, let text = headerText(c, "AXColumnHeaderUIElements", "AXColumnIndexRange", column) {
		return text
	}
	guard let table = table else { return nil }
	if let columns = getAttribute(table, kAXColumnsAttribute as String) as? [AXUIElement] {
		let match = columns.first { (getAttribute($0, kAXIndexAttribute as String) as? Int) == column }
			?? (column < columns.count ? columns[column] : nil)
		if let col = match, let header = getAttribute(col, kAXHeaderAttribute as String),
		   CFGetTypeID(header) == AXUIElementGetTypeID() {
			let text = textOf(header as! AXUIElement)
			if !text.isEmpty {
				return text
			}
		}
	}
	if let text = headerText(table, "AXColumnHeaderUIElements", "AXColumnIndexRange", column) {
		return text
	}
	if let top = findCell(inTable: table, row: 0, column: column) {
		return textOf(top)
	}
	return nil
}

func rowHeaderText(table: AXUIElement?, cell: AXUIElement?, row: Int) -> String? {
	if let c = cell, let text = headerText(c, "AXRowHeaderUIElements", "AXRowIndexRange", row) {
		return text
	}
	guard let table = table else { return nil }
	if let text = headerText(table, "AXRowHeaderUIElements", "AXRowIndexRange", row) {
		return text
	}
	var foundAny = false
	for column in 0..<2 {
		if let candidate = findCell(inTable: table, row: row, column: column) {
			foundAny = true
			let text = textOf(candidate)
			if !text.isEmpty {
				return text
			}
		}
	}
	return foundAny ? "" : nil
}

let args = CommandLine.arguments
guard args.count >= 3, let x = Double(args[1]), let y = Double(args[2]) else {
	print("ERROR usage: ax_table_position <x> <y> [row-header|column-header]")
	exit(1)
}
let mode = args.count >= 4 ? args[3] : nil
if let m = mode, m != "row-header" && m != "column-header" {
	print("ERROR unknown mode: \(m)")
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
var tableElement: AXUIElement?
var cellElement: AXUIElement?
var current: AXUIElement? = startElement
var hops = 0
var roleTrail: [String] = []

while let element = current, hops < 12 {
	let role = roleOf(element)
	roleTrail.append(role)
	// SwiftUI Tables and AppKit outline views report themselves as
	// AXOutline rather than AXTable, but expose the same rows/cells.
	if tableElement == nil && (role == "AXTable" || role == "AXOutline" || role == "AXGrid") {
		tableElement = element
	}

	if rowIndex == nil {
		rowIndex = getRangeStart(element, "AXRowIndexRange")
		if rowIndex != nil {
			cellElement = element
		}
	}
	if colIndex == nil {
		colIndex = getRangeStart(element, "AXColumnIndexRange")
	}
	// Without a mode only the indices are needed; with one, keep going to
	// find the table the cell belongs to as well.
	if rowIndex != nil && colIndex != nil && (mode == nil || tableElement != nil) {
		break
	}

	current = getParent(element)
	hops += 1
}

if (rowIndex == nil || colIndex == nil), let table = tableElement,
   let cell = findCell(inTable: table, atX: x, y: y) {
	cellElement = cellElement ?? cell
	rowIndex = rowIndex ?? getRangeStart(cell, "AXRowIndexRange")
	colIndex = colIndex ?? getRangeStart(cell, "AXColumnIndexRange")
}

if let r = rowIndex, let c = colIndex {
	if let m = mode {
		let header = m == "row-header"
			? rowHeaderText(table: tableElement, cell: cellElement, row: r)
			: columnHeaderText(table: tableElement, cell: cellElement, column: c)
		if let text = header {
			print("TEXT \(singleLine(text))")
		} else {
			print("NOCELL \(r) \(c) \(roleTrail.joined(separator: ">"))")
		}
	} else {
		print("OK \(r) \(c)")
	}
} else {
	let names = attributeNames(startElement)
	print("UNRESOLVED \(roleTrail.joined(separator: ">")) | \(names.joined(separator: ","))")
}
