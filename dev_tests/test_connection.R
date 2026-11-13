#!usr/bin/env Rscript

test_auth <- mnmdbAuth(user = "guest", database = "sandbox")
describe(test_auth)


mnmdb_connection <- mnmdbConnection(auth = test_auth)
describe(mnmdb_connection)

# Yeah. The thing MUST be "pass by value"; "pass by reference" is unavailable.
mnmdb_connection <- mnmdb_connection |> connect()

# double connection may not fail
mnmdb_connection <- mnmdb_connection |> connect()


S7::S7_class(mnmdb_connection)


# DBI::dbDisconnect(mnmdb_connection@database_connection)
print(DBI::dbIsValid(mnmdb_connection@database_connection))


DBI::dbWriteTable(
  conn = mnmdb_connection@database_connection,
  name = DBI::Id("test", "mtcars"),
  value = mtcars,
  overwrite = TRUE
)
# DBI::dbListTables(mnmdb_connection@database_connection)

test_cars <- dplyr::tbl(mnmdb_connection@database_connection, DBI::Id("test", "mtcars"))
test_cars |> knitr::kable()

