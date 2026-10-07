#!usr/bin/env Rscript

# https://github.com/r-dbi/RPostgres/issues/444

library("tidyverse")
library("mnmdb")

test_auth <- mnmdbAuth(user = "guest", database = "sandbox")


mnmdb_connection <- mnmdbConnection(auth = test_auth)
mnmdb_connection <- mnmdb_connection |> connect()


test <- dplyr::tbl(mnmdb_connection@database_connection, DBI::Id("playground", "test"))
test2 <- test |> dplyr::collect()



# test2 <- test2 %>%
#   mutate(
#     arr = unclass(arr)
#   )
# test2 |> glimpse()
# # this turns it into a chr


# test2 |> tidyr::unnest(vector)
# test2 |> mutate_at(vars(arr, vector), as.data.frame)
# test2 |> mutate_at(vars(arr, vector), as.numeric)

# test2 |> as.data.frame()
# test2 |> mutate(arr = unnest(arr))




test <- dplyr::tbl(mnmdb_connection@database_connection, DBI::Id("playground", "test"))
test3 <- test %>%
  mutate(
    arr = dbplyr::sql("array_to_json(arr)"),
    vector = dbplyr::sql("array_to_json(vector)")
  ) %>%
  collect()

test3 %>% glimpse()

test3 %>%
  mutate(
    arr = lapply(arr, jsonlite::fromJSON),
    vector = lapply(vector, jsonlite::fromJSON)
  ) %>%
  glimpse()

test3 %>%
  mutate(
    arr = lapply(arr, jsonlite::fromJSON),
    vector = lapply(vector, jsonlite::fromJSON)
  )

## ALTERNATIVE
# use string conversion
# https://www.postgresql.org/docs/18/functions-array.html#FUNCTION-ARRAY-TO-STRING
# https://www.postgresql.org/docs/18/functions-string.html#FUNCTION-STRING-TO-ARRAY

test <- dplyr::tbl(mnmdb_connection@database_connection, DBI::Id("playground", "test"))


test4 <- test %>%
  mutate(
    arr = dbplyr::sql("array_to_string(arr, ',', 'NULL')"),
    vector = dbplyr::sql("array_to_string(vector, ',', 'NULL')")
  ) %>%
  collect()

test4 %>% glimpse()

string_to_array <- \(arr_str) stringr::str_split(arr_str, pattern = ",")
string_array_to_int_array <- \(int_arrstr) purrr::map(string_to_array(int_arrstr), as.integer)

test4 %>%
  mutate_at(
    vars(arr, vector),
    string_array_to_int_array
  ) %>%
  glimpse()


# GENERALIZE

# requireNamespace(c("dbplyr", "jsonlite", "glue"))
# convert array to json using the postgres built-in `array_to_json`
# https://www.postgresql.org/docs/current/functions-json.html

## Oh, well, generalization with `mutate_at` is futile:
#  we would have to input `var_names` but convert data content
# sql_to_json <- \(field) dbplyr::sql("array_to_json(arr)")


requireNamespace("dbplyr", quietly = FALSE) # WTF?! "quietly" will suppress warnings...

data_uncollected <- dplyr::tbl(mnmdb_connection@database_connection, DBI::Id("playground", "test"))
array_columns <- c("arr", "vector")

data_converted <- data_uncollected
for (col in array_columns) {
  data_converted <- data_converted %>%
    mutate_at(
      vars(tidyselect::all_of(c(col))),
      \(dcol) dbplyr::sql(sprintf("array_to_string(%s, ',', 'NULL')", col))
    )

}
data_collected <- data_converted %>% collect()


string_to_array <- \(arr_str) stringr::str_split(arr_str, pattern = ",")
string_array_to_int_array <- \(iarr) lapply(string_to_array(iarr), FUN = as.integer)

data_final <- data_collected %>%
  mutate_at(
    vars(tidyselect::all_of(array_columns)),
    string_array_to_int_array
  )

data_final %>% glimpse()


# We should also be able to upload the data
data_upload <- data_final[1,]

data_upload[[1, "arr"]] <- list(c(1, 1))
data_upload[[1, "vector"]] <- list(c(1, 1))

# wrap_curls <- \(arr_str) paste0(c("ARRAY[", arr_str, "]"), collapse = "")
wrap_curls <- \(arr_str) paste0(c("{", arr_str, "}"), collapse = "")
listpaste <- \(arr) paste0(unlist(arr), collapse = ",")

# wrap_curls(listpaste(data_upload[[1, "arr"]]))
upload_prep <- \(x) wrap_curls(listpaste(x))
upload_2darr <- \(x) wrap_curls(listpaste(lapply(unlist(x), FUN = wrap_curls)))
# upload_2darr(data_upload[[1, "vector"]])

data_upload <- data_upload %>%
  mutate(
    arr = upload_prep(arr),
    vector = upload_2darr(vector)
  )

data_upload %>% glimpse()

rs <- DBI::dbWriteTable(
  mnmdb_connection@database_connection,
  DBI::Id("playground", "test"),
  data_upload,
  row.names = FALSE,
  overwrite = FALSE,
  append = TRUE,
  # binary = TRUE,
  # copy = FALSE,
  # field.types = c("arr" = "int[]", "vector" = "int[]")
  factorsAsCharacter = TRUE
)

# DELETE FROM "playground"."test" WHERE arr <@ '{1,1}';

