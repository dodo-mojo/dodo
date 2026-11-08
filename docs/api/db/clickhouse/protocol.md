# `dodo.db.clickhouse.protocol`

ClickHouse over HTTP, without I/O: request URLs, parameters, the RowBinaryWithNamesAndTypes result format, and errors.

Parameters travel as `param_p1=...` URL fields and the SQL names them with
their type, `{p1:UInt64}`, so a value is never spliced into the SQL.

## Aliases

### `DB`

```mojo
comptime DB = "clickhouse"
```

### `FORMAT`

```mojo
comptime FORMAT = "RowBinaryWithNamesAndTypes"
```

## Functions

### `percent_encode`

```mojo
def percent_encode(text: Span[UInt8]) -> String
```

### `escape_value`

```mojo
def escape_value(param: Param) -> List[UInt8]
```

A parameter in ClickHouse's escaped text format, which is how the server parses `param_*` values: backslash, tab and line breaks are escaped, NULL is `\N`.

### `query_string`

```mojo
def query_string(database: String, settings: List[Tuple[String, String]], params: List[Param], sql: String) raises -> String
```

`?database=...&default_format=...&param_p1=...` for one query.

Each parameter must be used: `{p1:Type}` for the first, `{p2:Type}`
for the second, and so on.

### `split_script`

```mojo
def split_script(sql: String) -> List[String]
```

Statements of a `;`-separated script. Semicolons inside quotes or comments don't split.

### `server_error`

```mojo
def server_error(status: Int, code: String, body: String) -> DbError
```

The error for a non-200 reply.

### `written_rows`

```mojo
def written_rows(summary: String) -> Int
```

`written_rows` from the X-ClickHouse-Summary header.

### `decode`

```mojo
def decode(body: Span[UInt8]) raises -> Rows
```

A whole result: the header (names, then types), then every row.
