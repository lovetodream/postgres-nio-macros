import PreparedStatementsPostgresNIO
import PostgresNIO
import Foundation

@Statement("SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self) FROM users WHERE \(bind: "age", Int.self) > age")
struct MyPreparedStatement {}

struct MyPreparedStatementOldWay: PostgresPreparedStatement {
    func decodeRow(_ row: PostgresRow) throws -> Row {
        let (v1, v2, v3) = try row.decode((UUID, String, Int).self)
        return Row(id: v1, name: v2, age: v3)
    }
    
    struct Row {
        let id: UUID
        let name: String
        let age: Int
    }

    static let sql: String = ""

    let age: Int

    func makeBindings() throws -> PostgresBindings {
        var bindings = PostgresBindings(capacity: 1)
        bindings.append(age)
        return bindings
    }
}

func myThing() {

}

@Statement("SELECT *")
struct MyOtherPreparedStatement {}

@available(macOS 14.0, *)
@Observable
final class MyObservable {}
