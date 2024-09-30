import PostgresNIO

/// A parsable String literal for the `@Statement` macro. It doesn't store anything and is completely useless outside of the `@Statement` declaration.
///
/// ```swift
/// @Statement("SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self) FROM users")
/// struct UsersStatement {}
/// ```
public struct _PostgresPreparedStatementString: ExpressibleByStringInterpolation, Sendable {
    public init(stringLiteral value: String) {}

    public init(stringInterpolation: StringInterpolation) {}

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        public init(literalCapacity: Int, interpolationCount: Int) {}

        public mutating func appendLiteral(_ literal: String) {}

        /// Adds a column, e.g. inside a `SELECT` statement.
        /// - Parameters:
        ///   - name: The column name in SQL.
        ///   - type: The type used to represent the column data in Swift.
        ///   - as: An optional alias for the column. It will be used in as an alias in SQL and the declaration Swifts `Row` struct.
        ///
        /// ```swift
        ///"SELECT \("id", UUID.self) FROM users"
        ///// -> SQL:   SELECT id FROM users
        ///// -> Swift: struct Row { let id: UUID }
        ///
        ///"SELECT \("user_id", UUID.self, as: userID) FROM users"
        ///// -> SQL: SELECT id as userID FROM users
        ///// -> SWIFT: struct Row { let userID: UUID }
        /// ```
        public mutating func appendInterpolation(
            _ name: String,
            _ type: (some PostgresDecodable).Type,
            as: String? = nil
        ) {}

        /// Adds a bind variable.
        /// - Parameters:
        ///   - bind: The name of the bind variable in Swift.
        ///   - type: The Swift type of the bind variable.
        public mutating func appendInterpolation(
            bind: String,
            _ type: (some PostgresDynamicTypeEncodable).Type
        ) {}
    }
}

/// Defines and implements conformance of the PostgresPreparedStatement protocol for Structs.
///
/// For example, the following code applies the `Statement` macro to the type `UsersStatement`:
/// ```swift
/// @Statement("SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self) FROM users WHERE \(bind: "age", Int.self) < age")
/// struct UsersStatement {}
/// ```
@attached(member, names: arbitrary)
@attached(extension, conformances: PostgresPreparedStatement)
public macro Statement(_ statement: _PostgresPreparedStatementString) =
    #externalMacro(module: "PostgresNIOMacrosPlugin", type: "StatementMacro")
