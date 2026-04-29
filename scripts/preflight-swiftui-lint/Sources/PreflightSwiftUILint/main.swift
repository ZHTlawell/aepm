import Foundation
import SwiftSyntax
import SwiftParser

// MARK: - Finding model

struct Finding: Codable {
    let ruleId: String
    let file: String
    let line: Int
    let column: Int
    let message: String
    let context: String
}

// MARK: - Lint visitor

final class LintVisitor: SyntaxVisitor {
    var findings: [Finding] = []
    let filename: String
    let converter: SourceLocationConverter

    init(filename: String, converter: SourceLocationConverter) {
        self.filename = filename
        self.converter = converter
        super.init(viewMode: .sourceAccurate)
    }

    // Walk every FunctionCallExpr once; dispatch based on call kind.
    override func visit(_ node: FunctionCallExprSyntax) -> SyntaxVisitorContinueKind {
        let calleeName = identifyCall(node)

        switch calleeName {
        case .buttonInit:
            checkButtonEmptyAction(node)
        case .modifier("onTapGesture"):
            checkOnTapGestureEmpty(node)
        case .modifier("frame"):
            checkFrameTouchTarget(node)
        default:
            break
        }

        return .visitChildren
    }

    // ios-pub-012 — UUID() default initializer on stored `id` property
    override func visit(_ node: VariableDeclSyntax) -> SyntaxVisitorContinueKind {
        checkUUIDDefaultID(node)
        checkAVFrameworkLocalVar(node)
        return .visitChildren
    }

    // ios-pub-071 (part 1) — string literals containing "/api/api"
    override func visit(_ node: StringLiteralExprSyntax) -> SyntaxVisitorContinueKind {
        checkDoubleAPIPrefix(node)
        return .visitChildren
    }

    // ios-pub-071 (part 2) — strict statusCode == 200 (parser yields SequenceExpr, not InfixOp)
    override func visit(_ node: SequenceExprSyntax) -> SyntaxVisitorContinueKind {
        checkStrictStatusCodeEquality(node)
        return .visitChildren
    }

    // MARK: - Call identification

    private enum CallKind: Equatable {
        case buttonInit
        case modifier(String)   // e.g. .frame(...), .onTapGesture { ... }
        case other
    }

    private func identifyCall(_ node: FunctionCallExprSyntax) -> CallKind {
        // Button(...) => calledExpression is DeclReferenceExprSyntax("Button")
        if let ref = node.calledExpression.as(DeclReferenceExprSyntax.self),
           ref.baseName.text == "Button" {
            return .buttonInit
        }
        // X.modifier(...) => calledExpression is MemberAccessExprSyntax
        if let member = node.calledExpression.as(MemberAccessExprSyntax.self) {
            return .modifier(member.declName.baseName.text)
        }
        return .other
    }

    // MARK: - Rule: ios-pub-011 — empty Button action

    private func checkButtonEmptyAction(_ node: FunctionCallExprSyntax) {
        guard let closure = extractActionClosure(node) else { return }
        guard isClosureEffectivelyEmpty(closure) else { return }

        let label = extractButtonLabel(node) ?? "(no label)"
        report(
            ruleId: "ios-pub-011",
            at: node.positionAfterSkippingLeadingTrivia,
            message: "Button action is empty or placeholder — user will tap with no response",
            context: "Button label: \(label)"
        )
    }

    // MARK: - Rule: ios-pub-011 — empty onTapGesture

    private func checkOnTapGestureEmpty(_ node: FunctionCallExprSyntax) {
        guard let closure = firstTrailingOrFirstClosureArg(node) else { return }
        guard isClosureEffectivelyEmpty(closure) else { return }

        report(
            ruleId: "ios-pub-011",
            at: node.positionAfterSkippingLeadingTrivia,
            message: "onTapGesture action is empty or placeholder",
            context: ".onTapGesture"
        )
    }

    // MARK: - Rule: ios-pub-010 — 44pt touch target

    private func checkFrameTouchTarget(_ node: FunctionCallExprSyntax) {
        guard isOnInteractiveChain(node) else { return }

        let dims = extractFrameDimensions(node)
        var violations: [(String, Int)] = []
        if let w = dims.width, w < 44 { violations.append(("width", w)) }
        if let h = dims.height, h < 44 { violations.append(("height", h)) }
        guard !violations.isEmpty else { return }

        let details = violations.map { "\($0.0)=\($0.1)pt" }.joined(separator: ", ")
        report(
            ruleId: "ios-pub-010",
            at: node.positionAfterSkippingLeadingTrivia,
            message: "Interactive element touch target below 44pt minimum (\(details))",
            context: ".frame on interactive element"
        )
    }

    // MARK: - Helpers: Button parsing

    private func extractActionClosure(_ call: FunctionCallExprSyntax) -> ClosureExprSyntax? {
        // 1) action: { ... } named argument
        for arg in call.arguments where arg.label?.text == "action" {
            if let closure = arg.expression.as(ClosureExprSyntax.self) {
                return closure
            }
        }
        // 2) Trailing closure (Button { action } label: { ... } OR Button(title) { action })
        if let trailing = call.trailingClosure {
            return trailing
        }
        return nil
    }

    private func extractButtonLabel(_ call: FunctionCallExprSyntax) -> String? {
        // Button("Text", action: ...) / Button("Text") { ... }
        if let first = call.arguments.first, first.label == nil,
           let strLit = first.expression.as(StringLiteralExprSyntax.self) {
            return strLit.segments.description.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // Button { action } label: { Text("...") }
        for arg in call.arguments where arg.label?.text == "label" {
            if let closure = arg.expression.as(ClosureExprSyntax.self) {
                return summarizeClosureLabel(closure)
            }
        }
        // Additional trailing closures via `additionalTrailingClosures` (label: closure)
        for extra in call.additionalTrailingClosures where extra.label.text == "label" {
            return summarizeClosureLabel(extra.closure)
        }
        // Button(action: { ... }) { LabelView } — trailing closure is the label
        // when `action:` is provided as a named argument.
        let hasActionArg = call.arguments.contains { $0.label?.text == "action" }
        if hasActionArg, let trailing = call.trailingClosure {
            return summarizeClosureLabel(trailing)
        }
        return nil
    }

    private func summarizeClosureLabel(_ closure: ClosureExprSyntax) -> String {
        // Look for Text("...") or Image(systemName: "...") inside the label closure
        let text = closure.description
        if let range = text.range(of: #"Text\("([^"]+)"\)"#, options: .regularExpression) {
            return String(text[range])
        }
        if let range = text.range(of: #"Image\(systemName:\s*"([^"]+)"\)"#, options: .regularExpression) {
            return String(text[range])
        }
        return "(complex label)"
    }

    private func firstTrailingOrFirstClosureArg(_ call: FunctionCallExprSyntax) -> ClosureExprSyntax? {
        if let trailing = call.trailingClosure { return trailing }
        for arg in call.arguments {
            if let closure = arg.expression.as(ClosureExprSyntax.self) {
                return closure
            }
        }
        return nil
    }

    // MARK: - Helpers: closure emptiness check

    private func isClosureEffectivelyEmpty(_ closure: ClosureExprSyntax) -> Bool {
        let statements = closure.statements
        // Truly empty body
        if statements.isEmpty { return true }

        // Every statement is either a print(...) call or a pure identifier placeholder
        for stmt in statements {
            if !isPlaceholderStatement(stmt.item) {
                return false
            }
        }
        return true
    }

    private func isPlaceholderStatement(_ item: CodeBlockItemSyntax.Item) -> Bool {
        // Only ExprStmt with a print(...) call is considered placeholder
        guard case let .expr(expr) = item else { return false }
        guard let call = expr.as(FunctionCallExprSyntax.self) else { return false }
        guard let ref = call.calledExpression.as(DeclReferenceExprSyntax.self) else { return false }
        return ref.baseName.text == "print"
    }

    // MARK: - Helpers: frame dimension extraction

    private struct FrameDims {
        var width: Int?
        var height: Int?
    }

    private func extractFrameDimensions(_ call: FunctionCallExprSyntax) -> FrameDims {
        var dims = FrameDims()
        for arg in call.arguments {
            guard let label = arg.label?.text else { continue }
            guard label == "width" || label == "height" else { continue }
            guard let intLit = arg.expression.as(IntegerLiteralExprSyntax.self) else { continue }
            guard let value = Int(intLit.literal.text) else { continue }
            if label == "width" { dims.width = value }
            if label == "height" { dims.height = value }
        }
        return dims
    }

    // MARK: - Helpers: interactive chain detection

    /// Walk up the parent chain. A `.frame(...)` call is considered "on an interactive element"
    /// if somewhere in the receiver chain we find a Button, NavigationLink, or a MemberAccessExpr
    /// whose method name hints at interactivity (onTapGesture, onLongPressGesture, button-like).
    private func isOnInteractiveChain(_ frameCall: FunctionCallExprSyntax) -> Bool {
        // The frame call's receiver is the base of the MemberAccessExpr inside calledExpression.
        // For A.frame(...) the calledExpression is MemberAccessExpr(base: A, name: frame).
        guard let member = frameCall.calledExpression.as(MemberAccessExprSyntax.self),
              let base = member.base else { return false }

        return chainContainsInteractive(ExprSyntax(base))
    }

    private func chainContainsInteractive(_ expr: ExprSyntax) -> Bool {
        var current: ExprSyntax? = expr
        var depth = 0
        while let node = current, depth < 40 {
            depth += 1

            // Direct reference to Button / NavigationLink constructor call
            if let call = node.as(FunctionCallExprSyntax.self) {
                if let ref = call.calledExpression.as(DeclReferenceExprSyntax.self) {
                    if ref.baseName.text == "Button" || ref.baseName.text == "NavigationLink" {
                        return true
                    }
                }
                // Modifier chain: A.someModifier(...) — recurse into base of member access
                if let member = call.calledExpression.as(MemberAccessExprSyntax.self) {
                    let name = member.declName.baseName.text
                    if interactiveModifierNames.contains(name) {
                        return true
                    }
                    current = member.base
                    continue
                }
            }

            // Raw member access A.b (no call) — recurse
            if let member = node.as(MemberAccessExprSyntax.self) {
                current = member.base
                continue
            }

            break
        }
        return false
    }

    private let interactiveModifierNames: Set<String> = [
        "onTapGesture",
        "onLongPressGesture",
        "highPriorityGesture",
        "simultaneousGesture"
    ]

    // MARK: - Rule: ios-pub-012 — UUID() default on stored id

    private func checkUUIDDefaultID(_ node: VariableDeclSyntax) {
        // Only flag in struct context — class instances init once, not per render.
        guard isInsideStruct(node) else { return }

        for binding in node.bindings {
            guard let pattern = binding.pattern.as(IdentifierPatternSyntax.self),
                  pattern.identifier.text == "id" else { continue }
            guard let initializer = binding.initializer else { continue }
            guard isUUIDCallExpr(initializer.value) else { continue }

            report(
                ruleId: "ios-pub-012",
                at: node.positionAfterSkippingLeadingTrivia,
                message: "Stored `id = UUID()` regenerates per init — ForEach will rebuild every row, can trigger watchdog 0x8BADF00D",
                context: "id default initializer in struct"
            )
        }
    }

    private func isUUIDCallExpr(_ expr: ExprSyntax) -> Bool {
        guard let call = expr.as(FunctionCallExprSyntax.self),
              let ref = call.calledExpression.as(DeclReferenceExprSyntax.self) else { return false }
        return ref.baseName.text == "UUID"
    }

    private func isInsideStruct(_ node: SyntaxProtocol) -> Bool {
        var parent: Syntax? = node.parent
        while let p = parent {
            if p.is(StructDeclSyntax.self) { return true }
            if p.is(ClassDeclSyntax.self) { return false }
            if p.is(ActorDeclSyntax.self) { return false }
            parent = p.parent
        }
        return false
    }

    // MARK: - Rule: ios-pub-013 — local AV framework instance

    private static let avFrameworkTypes: Set<String> = [
        "AVSpeechSynthesizer",
        "AVAudioPlayer",
        "AVAudioRecorder",
        "AVAudioEngine",
        "AVCaptureSession"
    ]

    private func checkAVFrameworkLocalVar(_ node: VariableDeclSyntax) {
        // Only flag when the var lives inside a function body (not type member).
        guard isInsideFunctionBody(node) else { return }

        for binding in node.bindings {
            guard let initializer = binding.initializer,
                  let typeName = initializerTypeName(initializer.value),
                  Self.avFrameworkTypes.contains(typeName) else { continue }

            let varName = binding.pattern.as(IdentifierPatternSyntax.self)?.identifier.text ?? "(?)"
            report(
                ruleId: "ios-pub-013",
                at: node.positionAfterSkippingLeadingTrivia,
                message: "\(typeName) instance `\(varName)` is a local variable — released when function returns, weak delegate callbacks will EXC_BAD_ACCESS. Store as instance property.",
                context: "local var \(typeName)"
            )
        }
    }

    private func initializerTypeName(_ expr: ExprSyntax) -> String? {
        guard let call = expr.as(FunctionCallExprSyntax.self) else { return nil }
        if let ref = call.calledExpression.as(DeclReferenceExprSyntax.self) {
            return ref.baseName.text
        }
        return nil
    }

    private func isInsideFunctionBody(_ node: SyntaxProtocol) -> Bool {
        var parent: Syntax? = node.parent
        while let p = parent {
            if p.is(FunctionDeclSyntax.self) { return true }
            if p.is(InitializerDeclSyntax.self) { return true }
            if p.is(AccessorDeclSyntax.self) { return true }
            if p.is(ClosureExprSyntax.self) { return true }
            // Hitting a type decl before any function => member-level, not local
            if p.is(StructDeclSyntax.self) || p.is(ClassDeclSyntax.self)
               || p.is(ActorDeclSyntax.self) || p.is(EnumDeclSyntax.self) {
                return false
            }
            parent = p.parent
        }
        return false
    }

    // MARK: - Rule: ios-pub-071 — API contract (double prefix + strict 200)

    private func checkDoubleAPIPrefix(_ node: StringLiteralExprSyntax) {
        let raw = node.segments.description
        guard raw.contains("/api/api") else { return }
        report(
            ruleId: "ios-pub-071",
            at: node.positionAfterSkippingLeadingTrivia,
            message: "URL string contains `/api/api` — base URL likely already includes `/api`, drop the prefix in the path",
            context: raw.trimmingCharacters(in: .whitespaces)
        )
    }

    private func checkStrictStatusCodeEquality(_ node: SequenceExprSyntax) {
        // Walk the sequence looking for `<status-ish>  ==  200` triples.
        let elements = Array(node.elements)
        guard elements.count >= 3 else { return }

        for i in 0..<(elements.count - 2) {
            let lhs = elements[i]
            let mid = elements[i + 1]
            let rhs = elements[i + 2]

            guard let op = mid.as(BinaryOperatorExprSyntax.self),
                  op.operator.text == "==" else { continue }

            let lhsIsStatus = exprMentionsStatusCode(lhs)
            let rhsIsStatus = exprMentionsStatusCode(rhs)
            guard lhsIsStatus || rhsIsStatus else { continue }

            let intSide = lhsIsStatus ? rhs : lhs
            guard let lit = intSide.as(IntegerLiteralExprSyntax.self),
                  lit.literal.text == "200" else { continue }

            report(
                ruleId: "ios-pub-071",
                at: node.positionAfterSkippingLeadingTrivia,
                message: "Strict `statusCode == 200` rejects valid 2xx responses (201/204/206) — use `(200..<300).contains(...)`",
                context: "\(lhs.description) == 200".trimmingCharacters(in: .whitespacesAndNewlines)
            )
            return
        }
    }

    private func exprMentionsStatusCode(_ expr: ExprSyntax) -> Bool {
        // Match identifiers / member accesses ending in "statusCode" or whose final segment is "code"
        if let ref = expr.as(DeclReferenceExprSyntax.self) {
            return isStatusCodeName(ref.baseName.text)
        }
        if let member = expr.as(MemberAccessExprSyntax.self) {
            return isStatusCodeName(member.declName.baseName.text)
        }
        return false
    }

    private func isStatusCodeName(_ name: String) -> Bool {
        return name == "statusCode" || name == "code" || name == "httpStatusCode"
    }

    // MARK: - Reporting

    private func report(ruleId: String, at position: AbsolutePosition, message: String, context: String) {
        let loc = converter.location(for: position)
        findings.append(Finding(
            ruleId: ruleId,
            file: filename,
            line: loc.line,
            column: loc.column,
            message: message,
            context: context
        ))
    }
}

// MARK: - Directory walk

func collectSwiftFiles(under root: String) -> [String] {
    let fm = FileManager.default
    var results: [String] = []
    guard let enumerator = fm.enumerator(atPath: root) else { return results }

    let skipPathFragments = [
        "/.build/", "/Pods/", "/DerivedData/", "/.swiftpm/", "/build/",
        "/Carthage/", "/node_modules/", "/.git/"
    ]

    while let rel = enumerator.nextObject() as? String {
        guard rel.hasSuffix(".swift") else { continue }
        let full = (root as NSString).appendingPathComponent(rel)
        if skipPathFragments.contains(where: { full.contains($0) }) { continue }
        // Skip test files and swift package manifests
        if rel.hasSuffix("Tests.swift") || rel.hasSuffix("Test.swift") { continue }
        if (rel as NSString).lastPathComponent == "Package.swift" { continue }
        results.append(full)
    }
    return results
}

// MARK: - Main

func main() {
    let args = CommandLine.arguments
    guard args.count >= 2 else {
        FileHandle.standardError.write(Data("usage: preflight-swiftui-lint <project_root> [--json]\n".utf8))
        exit(2)
    }

    let root = args[1]
    let jsonOutput = args.contains("--json")

    var isDir: ObjCBool = false
    guard FileManager.default.fileExists(atPath: root, isDirectory: &isDir), isDir.boolValue else {
        FileHandle.standardError.write(Data("error: not a directory: \(root)\n".utf8))
        exit(2)
    }

    let files = collectSwiftFiles(under: root)
    var allFindings: [Finding] = []

    for file in files {
        guard let data = FileManager.default.contents(atPath: file),
              let source = String(data: data, encoding: .utf8) else { continue }

        let sourceFile = Parser.parse(source: source)
        let converter = SourceLocationConverter(fileName: file, tree: sourceFile)
        let visitor = LintVisitor(filename: file, converter: converter)
        visitor.walk(sourceFile)
        allFindings.append(contentsOf: visitor.findings)
    }

    if jsonOutput {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        if let data = try? encoder.encode(allFindings),
           let str = String(data: data, encoding: .utf8) {
            print(str)
        }
    } else {
        printHumanReport(allFindings, scannedFiles: files.count, root: root)
    }

    // Exit code 1 if any findings, 0 otherwise — so scripts can gate on result
    exit(allFindings.isEmpty ? 0 : 1)
}

func printHumanReport(_ findings: [Finding], scannedFiles: Int, root: String) {
    print("═══════════════════════════════════════════════════")
    print("  SwiftUI Publish Lint — \(root)")
    print("  Scanned: \(scannedFiles) .swift files")
    print("  Findings: \(findings.count)")
    print("═══════════════════════════════════════════════════")

    if findings.isEmpty {
        print("\n✅ No violations found.\n")
        return
    }

    let grouped = Dictionary(grouping: findings, by: { $0.ruleId })
    for ruleId in grouped.keys.sorted() {
        let items = grouped[ruleId] ?? []
        print("\n[\(ruleId)] \(items.count) finding(s)")
        for f in items {
            let relFile = f.file.hasPrefix(root) ? String(f.file.dropFirst(root.count).drop(while: { $0 == "/" })) : f.file
            print("  \(relFile):\(f.line):\(f.column)")
            print("    \(f.message)")
            print("    context: \(f.context)")
        }
    }
    print("")
}

main()
