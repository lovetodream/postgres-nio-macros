import PreparedStatementsPostgresNIO
import PostgresNIO
import Foundation

let logger = Logger(label: "test")

let connection = try await PostgresConnection.connect(
    configuration: .init(
        host: "127.0.0.1",
        username: "timozacherl",
        password: nil,
        database: "postgres",
        tls: .disable
    ), id: 1, logger: logger
)

try await connection.query("CREATE TABLE IF NOT EXISTS users (id UUID UNIQUE, name TEXT, age INT)", logger: logger)

@Statement("INSERT INTO users (id, name, age) VALUES (\(bind: "id", UUID.self), \(bind: "name", String.self), \(bind: "age", Int.self))")
struct SeedUser {}

@Statement("SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self) FROM users WHERE \(bind: "age", Int.self) < age")
struct GetForAgeRestriction {}

_ = try? await connection.execute(
    SeedUser(id: UUID(uuidString: "A0A2AE7F-C398-4468-A276-6402639806DF")!, name: "Timo", age: 24),
    logger: logger
)

for try await row in try await connection.execute(GetForAgeRestriction(age: 18), logger: logger) {
    print(row)
}
