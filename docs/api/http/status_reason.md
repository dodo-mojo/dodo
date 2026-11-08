# `dodo.http.status_reason`

The standard reason phrase for each HTTP status code (RFC 9110 sec 15).

## Functions

### `status_reason`

```mojo
def status_reason(code: Int) -> String
```

The RFC 9110 reason phrase for ``code``.

A code without its own phrase gets its class name ("Client Error",
"Server Error", ...). A code outside 100-599 gets "Unknown".
