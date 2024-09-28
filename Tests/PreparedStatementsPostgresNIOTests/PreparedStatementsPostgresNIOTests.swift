import SwiftSyntax
import SwiftSyntaxBuilder
import SwiftSyntaxMacros
import SwiftSyntaxMacroExpansion
import SwiftSyntaxMacrosTestSupport
import XCTest
import PostgresNIO

// Macro implementations build for the host, so the corresponding module is not available when cross-compiling. Cross-compiled tests may still make use of the macro itself in end-to-end tests.
#if canImport(PreparedStatementsPostgresNIOMacros)
import PreparedStatementsPostgresNIOMacros

let testMacros: [String: MacroSpec] = [
    "Statement": MacroSpec(
        type: PreparedStatementsPostgresNIOMacro.self,
        conformances: ["PostgresPreparedStatement"]
    ),
]
#endif

final class PreparedStatementsPostgresNIOTests: XCTestCase {
    func testMacro() throws {
        #if canImport(PreparedStatementsPostgresNIOMacros)
        assertMacroExpansion(
            #"""
            @Statement("SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self) FROM users WHERE \(bind: "age", Int.self) > age")
            struct MyStatement {}
            """#,
            expandedSource: """
            struct MyStatement {
            
                struct Row {
                    let id: UUID
                    let name: String
                    let age: Int
                }
            
                static let sql = "SELECT id, name, age FROM users WHERE $1 > age"
            
                let age: Int
            
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
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroWithoutBinds() throws {
        #if canImport(PreparedStatementsPostgresNIOMacros)
        assertMacroExpansion(
            #"""
            @Statement("SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self) FROM users")
            struct MyStatement {}
            """#,
            expandedSource: """
            struct MyStatement {
            
                struct Row {
                    let id: UUID
                    let name: String
                    let age: Int
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
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }

    func testMacroOnInsertStatement() throws {
        #if canImport(PreparedStatementsPostgresNIOMacros)
        assertMacroExpansion(
            #"""
            @Statement("INSERT INTO users (id, name, age) VALUES (\(bind: "id", Int.self), \(bind: "name", String.self), \(bind: "age", Int.self))")
            struct MyStatement {}
            """#,
            expandedSource: """
            struct MyStatement {
            
                struct Row {
                }
            
                static let sql = "INSERT INTO users (id, name, age) VALUES ($1, $2, $3)"
            
                let id: Int
            
                let name: String
            
                let age: Int
            
                func makeBindings() throws -> PostgresBindings {
                    var bindings = PostgresBindings(capacity: 3)
                    bindings.append(id)
                    bindings.append(name)
                    bindings.append(age)
                    return bindings
                }
            
                func decodeRow(_ row: PostgresRow) throws -> Row {
                    return Row()
                }
            }
            
            extension MyStatement: PostgresPreparedStatement {
            }
            """,
            macroSpecs: testMacros
        )
        #else
        throw XCTSkip("macros are only supported when running tests for the host platform")
        #endif
    }
}
