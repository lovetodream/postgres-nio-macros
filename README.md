# PostgresNIOMacros

[![codecov](https://codecov.io/gh/lovetodream/postgres-nio-macros/graph/badge.svg?token=PLWUKYV0HO)](https://codecov.io/gh/lovetodream/postgres-nio-macros)

Macros for [PostgresNIO](https://github.com/vapor/postgres-nio).

## `@Statement(_:)`[^1]

[^1]: This macro was initially pitched to me by [@fabianfett](https://github.com/fabianfett).
 
Creates a `PostgresPreparedStatement` from a decorated query string.
 
```swift
import PostgresNIO
import PostgresNIOMacros

@Statement("SELECT \("id", UUID.self), \("name", String.self), \("age", Int.self) FROM users WHERE \(bind: "age", Int.self) < age")
struct UsersStatement {}

let connection: PostgresConnection = ...
let stream = try await connection.execute(UsersStatement(age: 18), logger: ...)
for try await user in stream {
    print(user.id, user.name, user.age)
}

```

<details>
<summary>Expanded source code.</summary>

```swift
struct UsersStatement {
    struct Row {
        var id: UUID
        var name: String
        var age: Int
    }

    static let sql = "SELECT id, name, age FROM users WHERE :1 < age"
    
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
extension UsersStatement: PostgresPreparedStatement {}
```
</details>
