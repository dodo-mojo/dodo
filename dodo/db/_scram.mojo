"""SCRAM-SHA-256 client (RFC 5802, RFC 7677), sans I/O.

PostgreSQL and MongoDB both authenticate with it; each wraps the three
messages in its own framing.

```mojo
var scram = ScramClient("dodo", password, database="postgres")
send(scram.client_first())
send(scram.client_final(server_first))
scram.verify(server_final)   # raises if the server can't prove it knows us
```
"""

from ..crypto.base64 import base64_decode, base64_encode
from ..crypto.digest import hmac_sha256_of, pbkdf2_hmac_sha256, sha256
from ..crypto.random import random_bytes
from .error import DbError


comptime _MIN_ITERATIONS = 4096
"""RFC 7677 section 4: a client must reject fewer."""
comptime _MAX_ITERATIONS = 10_000_000
"""Past this a malicious server makes the client burn CPU."""


struct ScramClient(Movable):
    var _user: String
    var _password: String
    var _nonce: String
    var _client_first_bare: String
    var _auth_message: String
    var _salted: List[UInt8]
    var _database: String

    def __init__(
        out self, user: String, password: String, database: String
    ) raises DbError:
        self._user = user
        self._password = password
        try:
            self._nonce = base64_encode(random_bytes(24))
        except e:
            raise DbError.auth(database, String("no randomness for SCRAM: ", e))
        self._client_first_bare = String()
        self._auth_message = String()
        self._salted = List[UInt8]()
        self._database = database

    def client_first(mut self) -> String:
        """`n,,n=<user>,r=<nonce>`. PostgreSQL ignores the user name here
        and passes an empty one; MongoDB needs it."""
        self._client_first_bare = (
            "n=" + _escape(self._user) + ",r=" + self._nonce
        )
        return "n,," + self._client_first_bare

    def client_final(mut self, server_first: String) raises DbError -> String:
        var server_nonce = String()
        var salt_text = String()
        var iterations = 0
        for part in server_first.split(","):
            var field = String(part)
            if field.startswith("r="):
                server_nonce = String(field[byte=2:])
            elif field.startswith("s="):
                salt_text = String(field[byte=2:])
            elif field.startswith("i="):
                try:
                    iterations = Int(String(field[byte=2:]))
                except:
                    raise self._fail("bad iteration count from server")
            elif field.startswith("m="):
                raise self._fail(
                    "server requires an unsupported SCRAM extension"
                )
        if (
            not server_nonce.startswith(self._nonce)
            or server_nonce == self._nonce
        ):
            raise self._fail("server nonce does not extend the client nonce")
        if iterations < _MIN_ITERATIONS or iterations > _MAX_ITERATIONS:
            raise self._fail(
                String("server asked for ", iterations, " iterations")
            )

        try:
            var salt = base64_decode(salt_text)
            self._salted = pbkdf2_hmac_sha256(
                self._password.as_bytes(), salt, iterations
            )
            var client_key = hmac_sha256_of(
                self._salted, "Client Key".as_bytes()
            )
            var stored_key = sha256(client_key)
            var without_proof = "c=biws,r=" + server_nonce
            self._auth_message = (
                self._client_first_bare
                + ","
                + server_first
                + ","
                + without_proof
            )
            var signature = hmac_sha256_of(
                stored_key, self._auth_message.as_bytes()
            )
            var proof = List[UInt8](capacity=len(client_key))
            for i in range(len(client_key)):
                proof.append(client_key[i] ^ signature[i])
            return without_proof + ",p=" + base64_encode(proof)
        except e:
            raise self._fail(String(e))

    def verify(self, server_final: String) raises DbError:
        """Check the server's signature: proof it holds our password hash."""
        if server_final.startswith("e="):
            raise self._fail(String(server_final[byte=2:]))
        try:
            var server_key = hmac_sha256_of(
                self._salted, "Server Key".as_bytes()
            )
            var expected = "v=" + base64_encode(
                hmac_sha256_of(server_key, self._auth_message.as_bytes())
            )
            # The signature is public once sent, so timing leaks nothing.
            if server_final.split(",")[0] == expected:
                return
        except e:
            raise self._fail(String(e))
        raise self._fail("server signature does not match")

    def _fail(self, message: String) -> DbError:
        return DbError.auth(self._database, String("SCRAM: ", message))


def _escape(name: String) -> String:
    """RFC 5802 section 5.1: `=` and `,` in a user name are escaped."""
    return name.replace("=", "=3D").replace(",", "=2C")
