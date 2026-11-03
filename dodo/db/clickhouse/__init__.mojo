"""ClickHouse, over its HTTP interface.

```mojo
from dodo.db.clickhouse import ClickHouse

var ch = ClickHouse("clickhouse://app:secret@localhost:8123/analytics")
var top = ch.query("select path, count() as hits from visits group by path limit {p1:UInt32}", 10)
```

Results use the RowBinaryWithNamesAndTypes format; parameters go as
`param_p1=...` fields, never into the SQL. See ADR-0009.
"""

from .client import ClickHouse
from .connection import ClickHouseConfig, ClickHouseConnection
