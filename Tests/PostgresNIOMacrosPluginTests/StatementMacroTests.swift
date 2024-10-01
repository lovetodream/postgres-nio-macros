import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosTestSupport
import XCTest

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(PostgresNIOMacrosPlugin)
import PostgresNIOMacrosPlugin

#if canImport(SwiftSyntax600)
let testMacros: [String: MacroSpec] = [
    "Statement": MacroSpec(type: StatementMacro.self, conformances: ["PostgresPreparedStatement"]),
]
#else
let testMacros: [String: Macro.Type] = [
    "Statement": StatementMacro.self,
]
#endif
#endif

final class StatementMacroTests: XCTestCase {
    #if canImport(SwiftSyntax600)
    let trailingNewline = "\n"
    #else
    let trailingNewline = ""
    #endif

    func testMacro() throws {
        #if canImport(PostgresNIOMacrosPlugin)
        assertMacroExpansion(
            #"""
            @Statement("SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self) FROM users WHERE \(bind: "age", Int.self) > age")
            struct MyStatement {}
            """#,
            expandedSource: """
            struct MyStatement {
            
                struct Row {
                    var id: UUID
                    var name: String
                    var age: Int
                }
            
                static let sql = "SELECT id, name, age FROM users WHERE $1 > age"
            
                var age: Int
            
                func makeBindings() throws -> PostgresBindings {
                    var bindings = PostgresBindings(capacity: 1)
                    bindings.append(age)
                    return bindings
                }
            
                func decodeRow(_ row: PostgresRow) throws -> Row {
                    let (id, name, age) = try row.decode((UUID, String, Int).self)
                    return Row(id: id, name: name, age: age)
                }\(trailingNewline)}
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithoutBinds() throws {
        #if canImport(PostgresNIOMacrosPlugin)
        assertMacroExpansion(
            #"""
            @Statement("SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self) FROM users")
            struct MyStatement {}
            """#,
            expandedSource: """
            struct MyStatement {
            
                struct Row {
                    var id: UUID
                    var name: String
                    var age: Int
                }
            
                static let sql = "SELECT id, name, age FROM users"
            
                func makeBindings() throws -> PostgresBindings {
                    return PostgresBindings()
                }
            
                func decodeRow(_ row: PostgresRow) throws -> Row {
                    let (id, name, age) = try row.decode((UUID, String, Int).self)
                    return Row(id: id, name: name, age: age)
                }\(trailingNewline)}
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroOnInsertStatement() throws {
        #if canImport(PostgresNIOMacrosPlugin)
        assertMacroExpansion(
            #"""
            @Statement("INSERT INTO users (id, name, age) VALUES (\(bind: "id", Int.self), \(bind: "name", String.self), \(bind: "age", Int.self))")
            struct MyStatement {}
            """#,
            expandedSource: """
            struct MyStatement {
            
                typealias Row = Void
            
                static let sql = "INSERT INTO users (id, name, age) VALUES ($1, $2, $3)"
            
                var id: Int
            
                var name: String
            
                var age: Int
            
                func makeBindings() throws -> PostgresBindings {
                    var bindings = PostgresBindings(capacity: 3)
                    bindings.append(id)
                    bindings.append(name)
                    bindings.append(age)
                    return bindings
                }
            
                func decodeRow(_ row: PostgresRow) throws -> Row {
                }\(trailingNewline)}
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithAliasInColumn() throws {
        #if canImport(PostgresNIOMacrosPlugin)
        assertMacroExpansion(
            #"""
            @Statement("SELECT \("user_id", UUID.self, as: "userID"), \("name", String.self), \("age", Int.self) FROM users WHERE \(bind: "age", Int.self) > age")
            struct MyStatement {}
            """#,
            expandedSource: """
            struct MyStatement {
            
                struct Row {
                    var userID: UUID
                    var name: String
                    var age: Int
                }
            
                static let sql = "SELECT user_id AS userID, name, age FROM users WHERE $1 > age"
            
                var age: Int
            
                func makeBindings() throws -> PostgresBindings {
                    var bindings = PostgresBindings(capacity: 1)
                    bindings.append(age)
                    return bindings
                }
            
                func decodeRow(_ row: PostgresRow) throws -> Row {
                    let (userID, name, age) = try row.decode((UUID, String, Int).self)
                    return Row(userID: userID, name: name, age: age)
                }\(trailingNewline)}
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithoutAnything() throws {
        #if canImport(PostgresNIOMacrosPlugin)
        assertMacroExpansion(
            #"""
            @Statement("SELECT id, name, age FROM users")
            struct MyStatement {}
            """#,
            expandedSource: """
            struct MyStatement {
            
                typealias Row = Void
            
                static let sql = "SELECT id, name, age FROM users"
            
                func makeBindings() throws -> PostgresBindings {
                    return PostgresBindings()
                }
            
                func decodeRow(_ row: PostgresRow) throws -> Row {
                }\(trailingNewline)}
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithEmptyString() throws {
        #if canImport(PostgresNIOMacrosPlugin)
        assertMacroExpansion(
            #"""
            @Statement("")
            struct MyStatement {}
            """#,
            expandedSource: """
            struct MyStatement {
            
                typealias Row = Void
            
                static let sql = ""
            
                func makeBindings() throws -> PostgresBindings {
                    return PostgresBindings()
                }
            
                func decodeRow(_ row: PostgresRow) throws -> Row {
                }\(trailingNewline)}
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroOnClassDoesNotWork() throws {
        #if canImport(PostgresNIOMacrosPlugin)
        #if canImport(SwiftSyntax600)
        let fixIts = [FixItSpec(message: "Replace 'class' with 'struct'")]
        #else
        let fixIts: [FixItSpec] = []
        #endif
        assertMacroExpansion(
            #"@Statement("")  class MyStatement {}"#,
            expandedSource: "class MyStatement {}",
            diagnostics: [
                DiagnosticSpec(
                    message: "'@Statement' can only be applied to struct types",
                    line: 1,
                    column: 1,
                    fixIts: fixIts
                )
            ],
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithOptionalBind() throws {
        #if canImport(PostgresNIOMacros)
        assertMacroExpansion(
            #"""
            @Statement("SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self) FROM users WHERE \(bind: "age", Int?.self) > age")
            struct MyStatement {}
            """#,
            expandedSource: """
                struct MyStatement {
                
                    struct Row {
                        var id: UUID
                        var name: String
                        var age: Int
                    }
                
                    static let sql = "SELECT id, name, age FROM users WHERE $1 > age"
                
                    var age: Int?
                
                    func makeBindings() throws -> PostgresBindings {
                        var bindings = PostgresBindings(capacity: 1)
                        bindings.append(age)
                        return bindings
                    }
                
                    func decodeRow(_ row: PostgresRow) throws -> Row {
                        let (id, name, age) = try row.decode((UUID, String, Int).self)
                        return Row(id: id, name: name, age: age)
                    }\(trailingNewline)}
                
                extension MyStatement: PostgresPreparedStatement {
                }
                """,
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithOptionalColumn() throws {
        #if canImport(PostgresNIOMacros)
        assertMacroExpansion(
            #"""
            @Statement("SELECT \("id", UUID?.self), \("name", String.self), \("age", Int.self) FROM users WHERE \(bind: "age", Int?.self) > age")
            struct MyStatement {}
            """#,
            expandedSource: """
                struct MyStatement {
                
                    struct Row {
                        var id: UUID?
                        var name: String
                        var age: Int
                    }
                
                    static let sql = "SELECT id, name, age FROM users WHERE $1 > age"
                
                    var age: Int?
                
                    func makeBindings() throws -> PostgresBindings {
                        var bindings = PostgresBindings(capacity: 1)
                        bindings.append(age)
                        return bindings
                    }
                
                    func decodeRow(_ row: PostgresRow) throws -> Row {
                        let (id, name, age) = try row.decode((UUID?, String, Int).self)
                        return Row(id: id, name: name, age: age)
                    }\(trailingNewline)}
                
                extension MyStatement: PostgresPreparedStatement {
                }
                """,
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithWithInvalidTypeDoesNotWork() throws {
        #if canImport(PostgresNIOMacros)
        assertMacroExpansion(
            #"""
            @Statement("SELECT \("id", UUID??.self), \("name", String.self), \("age", Int.self) FROM users WHERE \(bind: "age", Int?.self) > age")
            struct MyStatement {}
            """#,
            expandedSource: """
                struct MyStatement {}
                
                extension MyStatement: PostgresPreparedStatement {
                }
                """,
            diagnostics: [
                DiagnosticSpec(
                    message: "Cannot parse type for column with name 'id'",
                    line: 1,
                    column: 1
                )
            ],
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMultilineMacro() throws {
        #if canImport(PostgresNIOMacrosPlugin)
        assertMacroExpansion(
            #"""
            @Statement("""
            SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self)
            FROM users
            WHERE \(bind: "age", Int.self) > age
            """)
            struct MyStatement {}
            """#,
            expandedSource: #"""
            struct MyStatement {
            
                struct Row {
                    var id: UUID
                    var name: String
                    var age: Int
                }
            
                static let sql = """
                SELECT id, name, age
                FROM users
                WHERE $1 > age
                """

                var age: Int
            
                func makeBindings() throws -> PostgresBindings {
                    var bindings = PostgresBindings(capacity: 1)
                    bindings.append(age)
                    return bindings
                }
            
                func decodeRow(_ row: PostgresRow) throws -> Row {
                    let (id, name, age) = try row.decode((UUID, String, Int).self)
                    return Row(id: id, name: name, age: age)
                }\#(trailingNewline)}
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """#,
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}


#if !canImport(SwiftSyntax600)
func assertMacroExpansion(
    _ originalSource: String,
    expandedSource expectedExpandedSource: String,
    diagnostics: [DiagnosticSpec] = [],
    macroSpecs: [String: Macro.Type],
    testModuleName: String = "TestModule",
    testFileName: String = "test.swift",
    indentationWidth: Trivia = .spaces(4),
    file: StaticString = #file,
    line: UInt = #line
) {
    assertMacroExpansion(
        originalSource,
        expandedSource: expectedExpandedSource,
        diagnostics: diagnostics,
        macros: macroSpecs,
        testModuleName: testModuleName,
        testFileName: testFileName,
        indentationWidth: indentationWidth,
        file: file,
        line: line
    )
}
#endif
