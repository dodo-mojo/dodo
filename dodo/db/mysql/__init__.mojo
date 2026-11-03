"""MySQL and MariaDB, over the MySQL client/server protocol.

```mojo
from dodo.db.mysql import MySql

var db = MySql("mysql://dodo:secret@localhost:3306/app")
var users = db.query("select id, name from users where active = ?", True).to[User]()
```

Queries with parameters run as prepared statements, so values never touch
the SQL text. Authentication: `caching_sha2_password` (over TLS, or RSA on
a plain connection) and `mysql_native_password`. See ADR-0009.
"""

from .client import MySql, MySqlTransaction
from .connection import MySqlConfig, MySqlConnection
