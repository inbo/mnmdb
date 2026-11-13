#!usr/bin/env Rscript

# Behold, basic functionality to query a single table from a MNM database.


#' Query tables from MNE databases.
#'
#' @description
#' This function enables direct query of data from MNE databases.
#' The `subselect` arg can be used to query only a subset of fields.
#'
#' @param conn the mnmdb connection
#' @param ... Not used.
#'
#' @returns tibble or (spatial) data frame
#' @export
#'
query_table <- S7::new_generic("query_table", "conn")


#' The actual query of a table.
#'
#' @rdname query_table
#' @param table_id the `DBI::Id` of a table
#' @param subselect character vector of fields to select
#' @param ... Not used.
#'
S7::method(query_table, mnmdbConnection) <- function(conn, table_id, subselect = NA) {


  # optionally subselect
  if (is.scalar.na(subselect)) {
    subselect_pipe_function <- \(df) df
  } else {

    subselect_pipe_function <- function(df) {
      return(
        df |>
          dplyr::select(tidyselect::any_of(subselect))
      )
    }
  }

  is_spatial <- FALSE
  if (is_spatial) {
    # TODO not implemented / requires structure info

    # load and return data
    data <- sf::st_read(
        conn@database_connection,
        layer = table_id,
        geometry_column = "wkb_geometry"
      ) |>
      dplyr::select(-ogc_fid) |>
      subselect_pipe_function() |>
      sf::st_as_sf(crs = 31370)

    sf::st_geometry(data) <- "wkb_geometry"

  } else {

    ## else: non-spatial
    data <- dplyr::tbl(
        conn@database_connection,
        table_id
      ) |>
      subselect_pipe_function() |>
      dplyr::collect()

  }

  ## TODO handle data types, e.g. grts bigint, datetime(3)
  # grts_datatype_to_integer() |>
  # convert_df_datetime_types_to_character() |>
  # data |>
  #   unlist_keep_na(purrr::map(log_creation, convert_timestamp_to_ms_character))
  # ) |>


  # ensure "tibble" data type
  data <- data |> dplyr::as_tibble()

  return(data)

}
