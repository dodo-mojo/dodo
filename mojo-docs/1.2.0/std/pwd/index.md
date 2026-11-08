# `std.pwd`

Password database lookups for user account information.

The `pwd` package provides access to the Unix password database for retrieving
user account information. It offers a portable interface to query user records
by username or user ID on Unix-like systems. This package enables programs to
look up user details such as home directories, shells, and group memberships.

Use this package when you need to resolve user IDs to usernames, retrieve user
home directories, validate user existence, or access other user account
metadata on Unix-like systems.

## Modules

- [`std.pwd.pwd`](pwd.md): Provides access to the user password database on Unix-like systems.
