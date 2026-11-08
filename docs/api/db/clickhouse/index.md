# `dodo.db.clickhouse`

ClickHouse, over its HTTP interface.

```mojo
from dodo.db.clickhouse import ClickHouse

var ch = ClickHouse("clickhouse://app:secret@localhost:8123/analytics")
var top = ch.query("select path, count() as hits from visits group by path limit {p1:UInt32}", 10)
```

Results use the RowBinaryWithNamesAndTypes format; parameters go as
`param_p1=...` fields, never into the SQL. See ADR-0009.

## Modules

- [`dodo.db.clickhouse.client`](client.md): The ClickHouse pool most code uses.
- [`dodo.db.clickhouse.connection`](connection.md): One HTTP keep-alive connection to a ClickHouse server.
- [`dodo.db.clickhouse.protocol`](protocol.md): ClickHouse over HTTP, without I/O: request URLs, parameters, the RowBinaryWithNamesAndTypes result format, and errors.
