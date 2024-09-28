import SwiftCompilerPlugin
import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import Utility

public struct PreparedStatementsPostgresNIOMacro: ExtensionMacro, MemberMacro {
    public static func expansion(
        of node: AttributeSyntax,
        attachedTo declaration: some DeclGroupSyntax,
        providingExtensionsOf type: some TypeSyntaxProtocol,
        conformingTo protocols: [TypeSyntax],
        in context: some MacroExpansionContext
    ) throws -> [ExtensionDeclSyntax] {
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
        guard let elements = node.arguments?.as(LabeledExprListSyntax.self)?
            .first?.expression.as(StringLiteralExprSyntax.self)?.segments else {
            // TODO: Be more specific about this error
//            context.diagnose(Diagnostic(node: Syntax(node), message: PostgresNIODiagnostic.wrongArgument))
            return []
        }

        var sql = ""
        var columns: [(String, TokenSyntax)] = []
        var binds: [(String, TokenSyntax)] = []
        for element in elements {
            if let expression = element.as(ExpressionSegmentSyntax.self) {
                let interpolation = extractInterpolations(expression)
                switch interpolation {
                case .column(let name, let type):
                    columns.append((name, type))
                    sql.append(name)
                case .bind(let name, let type):
                    binds.append((name, type))
                    sql.append("$\(binds.count)")
                }
            } else if let expression = element.as(StringSegmentSyntax.self) {
                sql.append(expression.content.text)
            }
        }

        let rowStruct = StructDeclSyntax(
            structKeyword: .keyword(.struct, trailingTrivia: .space),
            name: .identifier("Row", trailingTrivia: .space),
            memberBlockBuilder: {
                for (name, type) in columns {
                    MemberBlockItemSyntax(
                        decl: VariableDeclSyntax(
                            bindingSpecifier: .keyword(.let, trailingTrivia: .space),
                            bindings: PatternBindingListSyntax(
                                itemsBuilder: {
                                    PatternBindingSyntax(
                                        pattern: IdentifierPatternSyntax(identifier: .identifier(name)),
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
            DeclSyntax(rowStruct),
            DeclSyntax(staticSQL),
        ] + bindings.map(DeclSyntax.init) + [
            DeclSyntax(makeBindings),
            DeclSyntax(decodeRow)
        ]
    }

    enum Interpolation {
        case column(String, TokenSyntax)
        case bind(String, TokenSyntax)
    }
    private static func extractInterpolations(_ node: ExpressionSegmentSyntax) -> Interpolation {
        let tupleElements = node.expressions
        guard tupleElements.count == 2 else {
            fatalError("Expected tuple with exactly two elements")
        }

        // First element needs to be the column name
        var iterator = tupleElements.makeIterator()
        let identifier = iterator.next()! as LabeledExprSyntax // works as tuple contains exactly two elements
        guard let type = iterator.next()!.expression.as(MemberAccessExprSyntax.self)?.base?.as(DeclReferenceExprSyntax.self) else {
            fatalError("expected something")
        }
        switch identifier.label?.identifier?.name {
        case "bind":
            guard let columnName = identifier.expression.as(StringLiteralExprSyntax.self)?
                .segments.first?.as(StringSegmentSyntax.self)?.content
                .text else {
                fatalError("Expected column name")
            }
            return .bind(columnName, type.baseName)
        default:
            guard let columnName = identifier.expression.as(StringLiteralExprSyntax.self)?
                .segments.first?.as(StringSegmentSyntax.self)?.content
                .text else {
                fatalError("Expected column name")
            }

            return .column(columnName, type.baseName)
        }
    }

    private static func makeBindings(for binds: [(String, TokenSyntax)]) -> FunctionDeclSyntax {
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

    private static func decodeRow(from columns: [(String, TokenSyntax)]) -> FunctionDeclSyntax {
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
                effectSpecifiers: FunctionEffectSpecifiersSyntax(throwsClause: ThrowsClauseSyntax(throwsSpecifier: .keyword(.throws))),
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
                                        for (column, _) in columns {
                                            TuplePatternElementSyntax(pattern: IdentifierPatternSyntax(identifier: .identifier(column)))
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
                                                            for (_, column) in columns {
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
                }
                CodeBlockItemSyntax(item: .stmt(StmtSyntax(ReturnStmtSyntax(expression: FunctionCallExprSyntax(
                    calledExpression: DeclReferenceExprSyntax(baseName: .identifier("Row")),
                    leftParen: .leftParenToken(),
                    rightParen: .rightParenToken(),
                    argumentsBuilder: {
                        for (column, _) in columns {
                            LabeledExprSyntax(label: column, expression: DeclReferenceExprSyntax(baseName: .identifier(column)))
                        }
                    }
                )))))
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
