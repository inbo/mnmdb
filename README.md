# `mnmdb`: Handle MNE Database Connections

This package facilitates connection to MNE (Monitoring Programme for the Natural Environment; NL: "Meetnetten Natuurlijk Milieu") databases.

Currently, those databases are not publicly available. 
The purpose of this package is to help colleagues connect to our servers and access the data, while preventing the exposure of credentials.


# WARNING: Under Construction

This package is a quick solution to help colleagues connect to databases and query data which were gathered in the broad scope of the MNE project ([broad context](https://github.com/inbo/n2khab-monitoring)).

It is work in progress, yet to be reviewed and tested.

In the future, it might be complementary to the tools already used in [`inbo/n2khab-mne-monitoring`](https://github.com/inbo/n2khab-mne-monitoring/tree/db_tooldev).


# Installation

```r
# install.packages("remotes")
remotes::install_github("inbo/mnmdb") # , ref = "HEAD")
```

Please note that the repository was originally called `n2khab-mne-database` and then renamed.
The R package loads under the name `mnmdb`.

# Usage

## Authentication Management

The main convenience of this database connector, and a major difference from [`inbo/inbodb`](https://github.com/inbo/inbodb), is the management of authentication and connection profiles. 
There are different ways to store authentication.

```r
library("mnmdb")
```

The naïve option (and still a valid fallback) is the direct hard-coding of connection parameters.

```r
auth <- mnmdb::mnmdbAuth(
  host = "127.0.0.1",
  port = "5432",
  user = "guest",
  # connect_passwordless = TRUE, # for use of a `.pgpass` file
  password = "abc123", # please do not store passwords like this!
  database = "sandbox"
)
```

Some of these parameters can be omitted and are replaced by defaults (e.g. `port`), though explicit user input takes precedence.

The connection password, no matter how it is provided, will be stored in the system keyring via R's [`keyring` package](https://keyring.r-lib.org/index.html) ([tutorial](https://tutorials.inbo.be/tutorials/r_keyring/)).
If no password is provided, it will be prompted.
There are multiple options to submit a password to the connector, thereby avoiding any prompt: 
(i) as a direct argument, e.g. via environment variables; 
(ii) stored in a connection config file which should be `.gitignore`d as described below; 
(iii) via [postgresql `.pgpass`](https://www.postgresql.org/docs/current/libpq-pgpass.html), in which case `password = NA` should be submitted to avoid prompts.

Please make sure to never hard-code or even git-commit any passwords.


More convenient for handling connections to multiple databases will be storage of config files.
Examples can be found in `/config_files/`; these contain the same connection parameters as above.

```ini
[testing_empty]
folder = dbstructure_test
host = 127.0.0.1
port = 5432
database = sandbox
```

An authentication object can load from these files, optionally supplementing manual arguments to override the conf content.

```r
auth <- mnmdb::mnmdbAuthConf(
  config_file = file.path("config_files", "test.conf"),
  database = "my_database"
)
mnmdb::describe(auth)
```

## Connection

With an `auth` authentication in place, connection is relatively simple.

```r
# a connection can be initialized and connected in one go
mnmdbconn <- mnmdb::mnmdbConnection(
    auth = mnmdb::mnmdbAuth(user = "guest", database = "sandbox")
  ) |> 
  mnmdb::connect()

print(mnmdbconn@is_connected)
mnmdb::describe(mnmdbconn)
```

After connection, the `mnmdbconn@database_connection` is accessible for direct usage with [`DBI`](https://dbi.r-dbi.org), e.g.

```r
DBI::dbWriteTable(
  conn = mnmdbconn@database_connection,
  name = DBI::Id("test", "mtcars"),
  value = mtcars,
  overwrite = TRUE
)
# DBI::dbListTables(mnmdbconn@database_connection)

test_cars <- dplyr::tbl(mnmdbconn@database_connection, DBI::Id("test", "mtcars"))
test_cars |> knitr::kable()


```

This "raw usage" is currently the only way to retrieve spatial information.

```r
data <- sf::st_read(
    mnmdbconn@database_connection,
    layer = DBI::Id("inbound", "Locations"),
    geometry_column = "wkb_geometry"
  ) |>
  dplyr::select(-ogc_fid) |>
  sf::st_as_sf(crs = 31370)
```


However, the next purpose of this package is to facilitate data queries (work in progress).


## Simplified Data Access

This package ships convenience functions to quickly access data from the MNM databases.

The most basic / important one would be `query_table`:

```r
mnmdbconn |> query_table(
    DBI::Id("test", "mtcars"),
    subselect = c("mpg", "cyl", "disp", "hp")
  )  |>
  head(5) |>
  knitr::kable()

```


This will work equally well for Views (given that you know the schema in which they are defined).


## Documentation

We try to document all functions extensively (guided by <https://roxygen2.r-lib.org/articles/rd-S7.html>). 

You might find the hint you were looking for in the documentation in R:

``` r
?mnmdb::mnmdbAuthConf
?mnmdb::mnmdbConnection
?mnmdb::connect
?mnmdb::query_table
```


