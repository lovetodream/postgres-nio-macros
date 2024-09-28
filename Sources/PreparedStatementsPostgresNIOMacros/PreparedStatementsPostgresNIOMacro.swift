import SwiftCompilerPlugin
import SwiftDiagnostics
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Utility

private struct InvalidDeclaration: DiagnosticMessage {
    let message = "'@Statement' can only be applied to struct types"
    let diagnosticID = MessageID(domain: "PostgresNIO", id: "statement-invalid-declaration")
    let severity: DiagnosticSeverity = .error
}
private struct InvalidDeclarationFixIt: FixItMessage {
    var introducer: TokenSyntax
    var message: String { "Replace '\(introducer.text)' with 'struct'" }
    let fixItID = MessageID(domain: "PostgresNIO", id: "statement-invalid-declaration-fix-it")
}

public struct PreparedStatementsPostgresNIOMacro: ExtensionMacro, MemberMacro {
    private typealias Column = (name: String, type: TokenSyntax, alias: String?)
    private typealias Bind = (name: String, type: TokenSyntax)

    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            return []
        }
        let protocols = protocols.map { InheritedTypeSyntax(type: $0) }
        return [
            ExtensionDeclSyntax(
                extendedType: type,
                inheritanceClause: .init(inheritedTypes: InheritedTypeListSyntax(protocols)),
                memberBlockBuilder: {}
            )
        ]
    }

    public static func expansion(of node: AttributeSyntax, providingMembersOf declaration: some DeclGroupSyntax, in context: some MacroExpansionContext) throws -> [DeclSyntax] {
        guard declaration.is(StructDeclSyntax.self) else {
            context.diagnose(Diagnostic(
                node: node,
                message: InvalidDeclaration(),
                fixIt: FixIt(message: InvalidDeclarationFixIt(introducer: declaration.introducer), changes: [
                    FixIt.Change.replace(
                        oldNode: Syntax(declaration.introducer),
                        newNode: Syntax(TokenSyntax.keyword(.struct))
                    )
                ])
            ))
            return []
        }

        // It is fine to force unwrap here, because the compiler ensures we receive this exact syntax tree here.
        let elements = node
            .arguments!.as(LabeledExprListSyntax.self)!
            .first!.expression.as(StringLiteralExprSyntax.self)!.segments

        var sql = ""
        var columns: [Column] = []
        var binds: [Bind] = []
        for element in elements {
            if let expression = element.as(ExpressionSegmentSyntax.self) {
                let interpolation = extractInterpolations(expression)
                switch interpolation {
                case .column(let column):
                    columns.append(column)
                    sql.append(column.name)
                    if let alias = column.alias {
                        sql.append(" AS \(alias)")
                    }
                case .bind(let bind):
                    binds.append(bind)
                    sql.append("$\(binds.count)")
                }
            } else if let expression = element.as(StringSegmentSyntax.self) {
                sql.append(expression.content.text)
            }
        }

        let rowDeclaration: DeclSyntax
        if columns.isEmpty {
            let rowAlias = TypeAliasDeclSyntax(name: .identifier("Row"), initializer: TypeInitializerClauseSyntax(value: IdentifierTypeSyntax(name: .identifier("Void"))))
            rowDeclaration = DeclSyntax(rowAlias)
        } else {
            let rowStruct = makeRowStruct(for: columns)
            rowDeclaration = DeclSyntax(rowStruct)
        }

        let staticSQL = VariableDeclSyntax(
            modifiers: [DeclModifierSyntax(name: .keyword(.static))],
            bindingSpecifier: .keyword(.let)
        ) {
            PatternBindingSyntax(
                pattern: IdentifierPatternSyntax(identifier: .identifier("sql")),
                initializer: InitializerClauseSyntax(value: StringLiteralExprSyntax(content: sql))
            )
        }

        let bindings = binds.map { name, type in
            VariableDeclSyntax(
                bindingSpecifier: .keyword(.let, leadingTrivia: .carriageReturnLineFeed, trailingTrivia: .space),
                bindings: PatternBindingListSyntax(
                    itemsBuilder: {
                        PatternBindingSyntax(
                            pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
                            typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: type))
                        )
                    }
                )
            )
        }

        let makeBindings = binds.isEmpty ? makeEmptyBindings() : makeBindings(for: binds)
        let decodeRow = decodeRow(from: columns)

        return [
            rowDeclaration,
            DeclSyntax(staticSQL),
        ] + bindings.map(DeclSyntax.init) + [
            DeclSyntax(makeBindings),
            DeclSyntax(decodeRow)
        ]
    }

    private enum Interpolation {
        case column(Column)
        case bind(Bind)
    }
    private static func extractInterpolations(_ node: ExpressionSegmentSyntax) -> Interpolation {
        let tupleElements = node.expressions
        precondition(tupleElements.count >= 2, "Expected tuple with two or more elements, less are impossible as the compiler already checks for it")

        // First element needs to be the column name
        var iterator = tupleElements.makeIterator()
        let identifier = iterator.next()! as LabeledExprSyntax // works as tuple contains at least two elements
        // Type can be force-unwrapped as the compiler ensures it is there.
        let type = iterator.next()!.expression.as(MemberAccessExprSyntax.self)!
            .base!.as(DeclReferenceExprSyntax.self)!
        // Same thing as with type.
        let name = identifier.expression.as(StringLiteralExprSyntax.self)!
            .segments.first!.as(StringSegmentSyntax.self)!.content.text
        switch identifier.label?.identifier?.name {
        case "bind":
            return .bind((name: name, type: type.baseName))
        default:
            let alias = iterator.next()?.expression.as(StringLiteralExprSyntax.self)?
                .segments.first?.as(StringSegmentSyntax.self)?.content.text

            return .column((name: name, type: type.baseName, alias: alias))
        }
    }

    private static func makeRowStruct(for columns: [Column]) -> StructDeclSyntax {
        StructDeclSyntax(
            structKeyword: .keyword(.struct, trailingTrivia: .space),
            name: .identifier("Row", trailingTrivia: .space),
            memberBlockBuilder: {
                for (name, type, alias) in columns {
                    MemberBlockItemSyntax(
                        decl: VariableDeclSyntax(
                            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
                            bindings: PatternBindingListSyntax(
                                itemsBuilder: {
                                    PatternBindingSyntax(
                                        pattern: IdentifierPatternSyntax(identifier: .identifier(alias ?? name)),
                                        typeAnnotation: TypeAnnotationSyntax(type: IdentifierTypeSyntax(name: type))
                                    )
                                }
                            )
                        )
                    )
                }
            },
            trailingTrivia: Trivia.newline
        )
    }

    private static func makeBindings(for binds: [Bind]) -> FunctionDeclSyntax {
        FunctionDeclSyntax(
            name: .identifier("makeBindings"),
            signature: FunctionSignatureSyntax(
                parameterClause: .init(parameters: []),
                effectSpecifiers: FunctionEffectSpecifiersSyntax(throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
                returnClause: ReturnClauseSyntax(type: TypeSyntax(stringLiteral: "PostgresBindings"))
            ),
            body: CodeBlockSyntax(statementsBuilder: {
                CodeBlockItemSyntax(
                    item: .decl(DeclSyntax(
                        VariableDeclSyntax(
                            bindingSpecifier: .keyword(.var),
                            bindings: PatternBindingListSyntax(itemsBuilder: {
                                PatternBindingSyntax(
                                    pattern: IdentifierPatternSyntax(identifier: .identifier("bindings")),
                                    initializer: InitializerClauseSyntax(value: FunctionCallExprSyntax(
                                        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("PostgresBindings")),
                                        leftParen: .leftParenToken(),
                                        arguments: [
                                            LabeledExprSyntax(
                                                label: "capacity",
                                                expression: IntegerLiteralExprSyntax(binds.count)
                                            )
                                        ],
                                        rightParen: .rightParenToken()
                                    ))
                                )
                            })
                        )
                    ))
                )
                for (bind, _) in binds {
                    CodeBlockItemSyntax(item: .expr(ExprSyntax(
                        FunctionCallExprSyntax(
                            calledExpression: MemberAccessExprSyntax(
                                base: DeclReferenceExprSyntax(baseName: .identifier("bindings")),
                                declName: DeclReferenceExprSyntax(baseName: .identifier("append"))
                            ),
                            leftParen: .leftParenToken(),
                            arguments: [LabeledExprSyntax(label: nil, expression: DeclReferenceExprSyntax(baseName: .identifier(bind)))],
                            rightParen: .rightParenToken()
                        )
                    )))
                }
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(ReturnStmtSyntax(
                    expression: DeclReferenceExprSyntax(baseName: .identifier("bindings"))
                ))))
            })
        )
    }

    private static func makeEmptyBindings() -> FunctionDeclSyntax {
        FunctionDeclSyntax(
            name: .identifier("makeBindings"),
            signature: FunctionSignatureSyntax(
                parameterClause: .init(parameters: []),
                effectSpecifiers: FunctionEffectSpecifiersSyntax(throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
                returnClause: ReturnClauseSyntax(type: TypeSyntax(stringLiteral: "PostgresBindings"))
            ),
            body: CodeBlockSyntax(statementsBuilder: {
                CodeBlockItemSyntax(
                    item: .stmt(StmtSyntax(
                        ReturnStmtSyntax(expression: FunctionCallExprSyntax(
                            calledExpression: DeclReferenceExprSyntax(baseName: .identifier("PostgresBindings")),
                            leftParen: .leftParenToken(),
                            arguments: [],
                            rightParen: .rightParenToken()
                        ))
                    ))
                )
            })
        )
    }

    private static func decodeRow(from columns: [Column]) -> FunctionDeclSyntax {
        FunctionDeclSyntax(
            name: .identifier("decodeRow"),
            signature: FunctionSignatureSyntax(
                parameterClause: .init(parameters: [
                    FunctionParameterSyntax(
                        firstName: .wildcardToken(),
                        secondName: .identifier("row"),
                        type: TypeSyntax(stringLiteral: "PostgresRow")
                    )
                ]),
                effectSpecifiers: FunctionEffectSpecifiersSyntax(
                    throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))
                ),
                returnClause: ReturnClauseSyntax(type: TypeSyntax(stringLiteral: "Row"))
            ),
            body: CodeBlockSyntax(statementsBuilder: {
                if !columns.isEmpty {
                    CodeBlockItemSyntax(item: .decl(DeclSyntax(
                        VariableDeclSyntax(
                            bindingSpecifier: .keyword(.let),
                            bindings: [
                                PatternBindingSyntax(
                                    pattern: TuplePatternSyntax(elementsBuilder: {
                                        for (column, _, alias) in columns {
                                            TuplePatternElementSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier(alias ?? column)))
                                        }
                                    }),
                                    initializer: InitializerClauseSyntax(
                                        value: TryExprSyntax(
                                            expression: FunctionCallExprSyntax(
                                                calledExpression: MemberAccessExprSyntax(
                                                    base: DeclReferenceExprSyntax(baseName: .identifier("row")),
                                                    name: .identifier("decode")
                                                ),
                                                leftParen: .leftParenToken(),
                                                rightParen: .rightParenToken(),
                                                argumentsBuilder: {
                                                    LabeledExprSyntax(expression: MemberAccessExprSyntax(
                                                        base: TupleExprSyntax(elementsBuilder: {
                                                            for (_, column, _) in columns {
                                                                LabeledExprSyntax(expression: DeclReferenceExprSyntax(baseName: column))
                                                            }
                                                        }),
                                                        declName: DeclReferenceExprSyntax(baseName: .keyword(.self))
                                                    ))
                                                }
                                            )
                                        )
                                    )
                                )
                            ]
                        )
                    )))
                    CodeBlockItemSyntax(item: .stmt(StmtSyntax(ReturnStmtSyntax(expression: FunctionCallExprSyntax(
                        calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Row")),
                        leftParen: .leftParenToken(),
                        rightParen: .rightParenToken(),
                        argumentsBuilder: {
                            for (column, _, alias) in columns {
                                LabeledExprSyntax(
                                    label: alias ?? column,
                                    expression: DeclReferenceExprSyntax(baseName: .identifier(alias ?? column))
                                )
                            }
                        }
                    )))))
                }
            })
        )
    }
}

@main
struct PreparedStatementsPostgresNIOPlugin: CompilerPlugin {
    let providingMacros: [Macro.Type] = [
        PreparedStatementsPostgresNIOMacro.self,
    ]
}
