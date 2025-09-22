import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosGenericTestSupport
import Testing

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(PostgresNIOMacrosPlugin)
import PostgresNIOMacrosPlugin

let testMacros: [String: MacroSpec] = [
    "Statement": MacroSpec(type: StatementMacro.self, conformances: ["PostgresPreparedStatement"]),
]

let macrosAvailable = true
#else
let macrosAvailable = false
#endif

@Suite(.enabled(if: macrosAvailable, "macros are only supported when running tests for the host platform"))
struct StatementMacroTests {

    @Test func macro() throws {
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
                }
            }
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func macroWithoutBinds() throws {
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
                }
            }
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func macroOnInsertStatement() throws {
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
                }
            }
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func macroWithAliasInColumn() throws {
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
                }
            }
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func macroWithoutAnything() throws {
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
                }
            }
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func macroWithEmptyString() throws {
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
                }
            }
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func macroOnClassDoesNotWork() throws {
        #if canImport(PostgresNIOMacrosPlugin)
        let fixIts = [FixItSpec(message: "Replace 'class' with 'struct'")]
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
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func macroWithOptionalBind() throws {
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
                        if let age {
                            bindings.append(age)
                        } else {
                            bindings.appendNull()
                        }
                        return bindings
                    }
                
                    func decodeRow(_ row: PostgresRow) throws -> Row {
                        let (id, name, age) = try row.decode((UUID, String, Int).self)
                        return Row(id: id, name: name, age: age)
                    }
                }
                
                extension MyStatement: PostgresPreparedStatement {
                }
                """,
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func macroWithOptionalColumn() throws {
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
                        if let age {
                            bindings.append(age)
                        } else {
                            bindings.appendNull()
                        }
                        return bindings
                    }
                
                    func decodeRow(_ row: PostgresRow) throws -> Row {
                        let (id, name, age) = try row.decode((UUID?, String, Int).self)
                        return Row(id: id, name: name, age: age)
                    }
                }
                
                extension MyStatement: PostgresPreparedStatement {
                }
                """,
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func macroWithWithInvalidTypeDoesNotWork() throws {
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
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func multilineMacro() throws {
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
                }
            }
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """#,
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }

    @Test func encodableArrayMacro() throws {
        #if canImport(PostgresNIOMacrosPlugin)
        assertMacroExpansion(
            #"""
            @Statement("""
            SELECT \("names", [String].self), \("memberOf", [Int]?.self)
            WHERE names = \(bind: "names", [String].self) OR memberOf = \(bind: "memberOf", [Int]?.self)
            FROM groups
            """)
            struct MyStatement {}
            """#,
            expandedSource: #"""
            struct MyStatement {
            
                struct Row {
                    var names: [String]
                    var memberOf: [Int]?
                }
            
                static let sql = """
                SELECT names, memberOf
                WHERE names = $1 OR memberOf = $2
                FROM groups
                """
            
                var names: [String]
            
                var memberOf: [Int]?
            
                func makeBindings() throws -> PostgresBindings {
                    var bindings = PostgresBindings(capacity: 2)
                    bindings.append(names)
                    if let memberOf {
                        bindings.append(memberOf)
                    } else {
                        bindings.appendNull()
                    }
                    return bindings
                }
            
                func decodeRow(_ row: PostgresRow) throws -> Row {
                    let (names, memberOf) = try row.decode(([String], [Int]?).self)
                    return Row(names: names, memberOf: memberOf)
                }
            }
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """#,
            macroSpecs: testMacros,
            failureHandler: {
                Issue.record(
                    "\($0.message)",
                    sourceLocation: .init(
                        fileID: $0.location.fileID,
                        filePath: $0.location.filePath,
                        line: $0.location.line,
                        column: $0.location.column
                    )
                )
            }
        )
        #endif
    }
}
