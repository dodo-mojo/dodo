"""The standard reason phrase for each HTTP status code (RFC 9110 sec 15)."""


def status_reason(code: Int) -> String:
    """The RFC 9110 reason phrase for ``code``.

    A code without its own phrase gets its class name ("Client Error",
    "Server Error", ...). A code outside 100-599 gets "Unknown".
    """
    if code == 100:
        return "Continue"
    if code == 101:
        return "Switching Protocols"
    if code == 200:
        return "OK"
    if code == 201:
        return "Created"
    if code == 202:
        return "Accepted"
    if code == 204:
        return "No Content"
    if code == 206:
        return "Partial Content"
    if code == 301:
        return "Moved Permanently"
    if code == 302:
        return "Found"
    if code == 303:
        return "See Other"
    if code == 304:
        return "Not Modified"
    if code == 307:
        return "Temporary Redirect"
    if code == 308:
        return "Permanent Redirect"
    if code == 400:
        return "Bad Request"
    if code == 401:
        return "Unauthorized"
    if code == 403:
        return "Forbidden"
    if code == 404:
        return "Not Found"
    if code == 405:
        return "Method Not Allowed"
    if code == 406:
        return "Not Acceptable"
    if code == 408:
        return "Request Timeout"
    if code == 409:
        return "Conflict"
    if code == 410:
        return "Gone"
    if code == 411:
        return "Length Required"
    if code == 412:
        return "Precondition Failed"
    if code == 413:
        return "Content Too Large"
    if code == 414:
        return "URI Too Long"
    if code == 415:
        return "Unsupported Media Type"
    if code == 416:
        return "Range Not Satisfiable"
    if code == 417:
        return "Expectation Failed"
    if code == 422:
        return "Unprocessable Content"
    if code == 426:
        return "Upgrade Required"
    if code == 429:
        return "Too Many Requests"
    if code == 431:
        return "Request Header Fields Too Large"
    if code == 500:
        return "Internal Server Error"
    if code == 501:
        return "Not Implemented"
    if code == 502:
        return "Bad Gateway"
    if code == 503:
        return "Service Unavailable"
    if code == 504:
        return "Gateway Timeout"
    if code == 505:
        return "HTTP Version Not Supported"
    return _class_reason(code)


def _class_reason(code: Int) -> String:
    """The name of the status class ``code`` belongs to."""
    if code >= 100 and code < 200:
        return "Informational"
    if code >= 200 and code < 300:
        return "Successful"
    if code >= 300 and code < 400:
        return "Redirection"
    if code >= 400 and code < 500:
        return "Client Error"
    if code >= 500 and code < 600:
        return "Server Error"
    return "Unknown"
