//
//  File.swift
//  PreparedStatementsPostgresNIO
//
//  Created by Timo Zacherl on 26.09.24.
//

import PostgresNIO

public struct _PostgresPreparedStatement: ExpressibleByStringInterpolation {
    public let sql: String
    let columns: [(name: String, type: String)]
    let binds: [(name: String, type: String)]

    public init(stringLiteral value: String) {
        sql = value
        columns = []
        binds = []
    }

    public init(stringInterpolation: StringInterpolation) {
        self.sql = stringInterpolation.sql
        self.columns = stringInterpolation.columns
        self.binds = stringInterpolation.binds
    }

    public struct StringInterpolation: StringInterpolationProtocol {
        public typealias StringLiteralType = String

        var sql: String
        var columns: [(name: String, type: String)]
        var binds: [(name: String, type: String)]

        public init(literalCapacity: Int, interpolationCount: Int) {
            sql = ""
            sql.reserveCapacity(literalCapacity)
            columns = []
            columns.reserveCapacity(interpolationCount)
            binds = []
            binds.reserveCapacity(interpolationCount)
        }

        public mutating func appendLiteral(_ literal: String) {
            sql.append(literal)
        }

        public mutating func appendInterpolation<T: PostgresDecodable>(_ name: String, _ type: T.Type) {
            sql.append(name)
            columns.append((name, String(reflecting: type)))
        }

        public mutating func appendInterpolation<T: PostgresDynamicTypeEncodable>(bind: String, _ type: T.Type) {
            binds.append((bind, String(reflecting: type)))
            sql.append("$\(binds.count)")
        }
    }
}
