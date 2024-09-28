import PostgresNIO
import Utility

@attached(member, names: arbitrary)
@attached(extension, conformances: PostgresPreparedStatement)
public macro Statement(_ statement: _PostgresPreparedStatement) = #externalMacro(module: "PreparedStatementsPostgresNIOMacros", type: "PreparedStatementsPostgresNIOMacro")
