import PostgresNIO
import PostgresNIOMacros
import Logging
import Testing

@Suite
final class StatementTests {
    private let logger = Logger(label: "PostgresNIOMacrosTests")
    private let client: PostgresClient
    private let running: Task<Void, Error>

    init() throws {
        #expect(isLoggingConfigured)
        let client = PostgresClient(
            configuration: .init(
                host: env("PSQL_HOST") ?? "127.0.0.1",
                port: env("PSQL_PORT").flatMap(Int.init) ?? 5432,
                username: env("PSQL_USER") ?? "postgres",
                password: env("PSQL_PASSWORD"),
                database: env("PSQL_DATABASE") ?? "postgres",
                tls: .prefer(.clientDefault)
            )
        )
        self.client = client
        self.running = Task { await client.run() }
    }

    deinit {
        running.cancel()
    }

    @Test
    func simpleSelects() async throws {
        try await self.client.withConnection { connection in
            let stream1 = try await connection.execute(SimpleNumberSelect(), logger: logger)
            var stream1Count = 0
            for try await row in stream1 {
                #expect(row.count == 1)
                stream1Count += 1
            }
            #expect(stream1Count == 1)
            let stream2 = try await connection.execute(SimpleNumberSelectWithWhereClause(minCount: 1), logger: logger)
            var stream2Count = 0
            for try await row in stream2 {
                #expect(row.count == 1)
                stream2Count += 1
            }
            #expect(stream2Count == 1)
            let stream3 = try await connection.execute(SimpleNullSelect(), logger: logger)
            var stream3Count = 0
            for try await row in stream3 {
                #expect(row.count == nil)
                stream3Count += 1
            }
            #expect(stream3Count == 1)
            let stream4 = try await connection.execute(SimpleSelectWithOptionalWhereClause(minCount: nil), logger: logger)
            var stream4Count = 0
            for try await _ in stream4 {
                stream4Count += 1
            }
            #expect(stream4Count == 0)
        }
    }

    @Test
    func arraySelects() async throws {
        do {
            try await self.client.withConnection { connection in
                let stream1 = try await connection.execute(ArraySelect(exact: ["1"]), logger: logger)
                var stream1Count = 0
                for try await row in stream1 {
                    #expect(row.value == ["1", "2", "3", "4"])
                    stream1Count += 1
                }
                #expect(stream1Count == 1)
            }
        } catch {
            print(String(reflecting: error))
            throw error
        }
    }
}

@Statement("SELECT \("1", Int.self, as: "count")")
private struct SimpleNumberSelect {}

@Statement("SELECT \("1", Int.self, as: "count") WHERE 1 >= \(bind: "minCount", Int.self)")
private struct SimpleNumberSelectWithWhereClause {}

@Statement("SELECT \("NULL", Int?.self, as: "count")")
private struct SimpleNullSelect {}

@Statement("SELECT \("1", Int.self, as: "count") WHERE \(bind: "minCount", Int?.self) != 0")
private struct SimpleSelectWithOptionalWhereClause {}

@Statement("""
SELECT \("string_to_array('1,2,3,4', ',')", [String].self, as: "value") 
WHERE \(bind: "exact", [String].self) = string_to_array('1', '') 
""")
private struct ArraySelect {}

func env(_ name: String) -> String? {
    getenv(name).flatMap { String(cString: $0) }
}

extension Logger {
    static func getLogLevel() -> Logger.Level {
        env("LOG_LEVEL").flatMap {
            Logger.Level(rawValue: $0)
        } ?? .debug
    }
}

let isLoggingConfigured: Bool = {
    LoggingSystem.bootstrap { label in
        var handler = StreamLogHandler.standardOutput(label: label)
        handler.logLevel = Logger.getLogLevel()
        return handler
    }
    return true
}()
