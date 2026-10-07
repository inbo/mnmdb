#!usr/bin/env Rscript

# This file contains the mnmdb authentication object.
# It handles credentials from user input, configs, or 
# default settings.


#' Authentication for mnmdb via connection parameters
#'
#' Manage authentification storage for connections to mnm databases.
#' In particular, the password is stored in the system keyring, and
#' never leaves the constructor function.
#'
#' @param host the host address (IP or url); default '127.0.0.1'
#' @param port on which the host listens for input; default '5432'
#' @param database name of the database to access (mandatory)
#' @param user username to get connected (mandatory)
#' @param password (optional) password to connect;
#'            will be prompted if no password is provided by the user
#' @param connect_passwordless option to connect without password via .pgpass
#' @param ... not used (consturctor)
#'
#' @examples
#' \dontrun{
#'   auth <- mnmdb::mnmdbAuth(
#'     user = "guest",
#'     database = "sandbox",
#'     connect_passwordless = TRUE # optional for use of `~/.pgpass`
#'   )
#'   auth <- mnmdbAuth(
#'     host = "127.0.0.1",
#'     port = "5432",
#'     user = "guest",
#'     password = "abc123", # avoid and do not share plaintext passwords!
#'     database = "sandbox"
#'   )
#' }
#'
#' @export
#'
mnmdbAuth <- S7::new_class(
  name = "mnmdbAuth",
  properties = list(
    host = S7::new_property(
      class = S7::class_character | NULL,
      default = "127.0.0.1"
    ),
    port = S7::new_property(
      class = S7::class_numeric | S7::class_character | NULL,
      default = "5432"
    ),
    database = S7::class_character,
    user = S7::class_character,
    password = S7::new_property(
      class = S7::class_character | NULL,
      default = NULL
    ),
    connect_passwordless = S7::new_property(
      class = S7::class_logical | NULL,
      default = FALSE
    ),
    keyring_label = S7::new_property(
      class = S7::class_character | NULL,
      default = "mnmdb_temp"
    )
  ),
  constructor = function(...) {
    # highest precedence: user input
    params <- list(...)

    # some arguments are mandatory
    if (is.null(params$user)) {
      stop(
        "No user provided. Please authenticate as a valid MNE database user via `user = `."
      )
    }
    if (is.null(params$database)) {
      stop(
        "No database user provided. Please provide the database via the `database = ` argument."
      )
    }
    if (is.integer(params$port)) {
      params$port <- as.character(params$port)
    }

    # overwrite default parameters (for those not given by user)
    for (p in names(auth_parameter_defaults)) {
      if (is.null(params[[p]])) {
        params[[p]] <- auth_parameter_defaults[[p]]
      }
    }

    ## password and keyring
    # if no password is provided, prompt one
    password_exists <- FALSE
    if (is.null(params[["password"]])) {

      if (params$keyring_label %in% keyring::keyring_list()$keyring) {
        existing <- keyring::key_list(keyring = params$keyring_label)
        existing_service <- existing$service == "mnmdb_credentials"
        existing_user <- existing$username == params$user

        password_exists <- sum(existing_service & existing_user) > 0
        # message("Password exists.")
      }

    }

    # write password to keyring
    if (isFALSE(as.logical(params[["connect_passwordless"]]))
        && (isFALSE(is.null(params[["password"]]))
        || isFALSE(password_exists))
      ) {
      store_db_password(
        params$keyring_label,
        service = "mnmdb_credentials",
        username = params$user,
        password = params$password
      )
    }

    # remove password so that it does not retain in memory
    params[["password"]] <- NULL

    # enforce data type of non-character params
    params$connect_passwordless <- as.logical(params$connect_passwordless)
    # print(params)

    return(
      S7::new_object(`mnmdbAuth`,
        host = params$host,
        port = params$port,
        database = params$database,
        user = params$user,
        password = NULL,
        connect_passwordless = params$connect_passwordless,
        keyring_label = params$keyring_label
      )
    )

    # return(do.call("S7::new_object", c(list(`mnmdbAuth`), params)))
  }
)



#' Authentication for mnmdb via config file
#'
#' Just as `mnmdbAuth`, but with the extra option to store authentication parameters
#' in a config file (e.g. in the `config_files` folder).
#'
#' @param config_file file.path to a config file to load with `configr`
#' @param connection_profile (optional) number or name of the
#'        parameter block in `.conf` file (if there are multiple)
#' @param ... not used (consturctor)
#'
#' @examples
#' \dontrun{
#'   auth <- mnmdb::mnmdbAuthConf(file.path("config_files", "test.conf"))
#'   describe(auth)
#' }
#'
#' @export
#'
mnmdbAuthConf <- S7::new_class(
  name = "mnmdbAuthConf",
  parent = mnmdbAuth,
  properties = list(
    config_file = S7::class_character,
    connection_profile = S7::new_property(
      class = S7::class_numeric | S7::class_character | NULL,
      default = 1
    )
  ),
  constructor = function(config_file, ...) {
    # fallback 0: user input
    # fallback 1: config file
    # fallback 2: defaults

    # highest precedence: user input
    params <- list(...)

    # if user does not provide input, check config
    copro <- params$connection_profile
    if (is.null(copro)) copro <- 1
    config_params <- configr::read.config(file = config_file)[[copro]]

    for (p in names(config_params)) {
      if (is.null(params[[p]])) {
        params[[p]] <- config_params[[p]]
      }
    }

    # some arguments are mandatory
    if (is.null(params$user)) {
      stop(
        "No user provided. Please authenticate as a valid MNE database user via `user = `."
      )
    }
    if (is.null(params$database)) {
      stop(
        "No database user provided. Please provide the database via the `database = ` argument."
      )
    }
    if (is.integer(params$port)) {
      params$port <- as.character(params$port)
    }

    # overwrite default parameters (for those not given by user)
    for (p in names(auth_parameter_defaults)) {
      if (is.null(params[[p]])) {
        params[[p]] <- auth_parameter_defaults[[p]]
      }
    }

    ## password and keyring
    # if no password is provided, prompt one
    if (is.null(params[["password"]])) {
      password_exists <- FALSE

      if (params$keyring_label %in% keyring::keyring_list()$keyring) {
        existing <- keyring::key_list(keyring = params$keyring_label)
        existing_service <- existing$service == "mnmdb_credentials"
        existing_user <- existing$username == params$user

        password_exists <- sum(existing_service & existing_user) > 0
        # message("Password exists.")
      }

    }

    # write password to keyring
    if (isFALSE(is.null(params[["password"]])) || isFALSE(password_exists)) {
      store_db_password(
        params$keyring_label,
        service = "mnmdb_credentials",
        username = params$user,
        password = params$password
      )
    }


    # remove password so that it does not retain in memory
    params[["password"]] <- NULL

    # enforce data type of non-character params
    params$connect_passwordless <- as.logical(params$connect_passwordless)

    return(
      S7::new_object(`mnmdbAuthConf`,
        config_file = config_file,
        connection_profile = params$connection_profile,
        host = params$host,
        port = params$port,
        database = params$database,
        user = params$user,
        connect_passwordless = params$connect_passwordless,
        password = NULL
      )
    )
  },
  validator = function(self) {
    if (isFALSE(is.character(self@config_file))) {
      return("The config file argument @config_file must be a character.")
    }
    if (isFALSE(file.exists(self@config_file))) {
      return(glue::glue("The config file '{self@config_file}' does not exist!"))
    }
  }
)

# props(x) <- list(name1 = val1, name2 = val2) modifies an existing object by setting multiple properties simultaneously.


#' description of database auth
#'
#' @rdname describe
#' @param ... Not used.
#'
S7::method(describe, mnmdbAuth) <- function(x) {
  auth <- x
  paste0(
    "Authentication for ",
    auth@user, " @ ",
    auth@host, ":", auth@port,
    " -d ", auth@database
  )
}



#_______________________________________________________________________________
# default parameters
# NOTE: non-character data types must be enforced in the constructors
auth_parameter_defaults <- c(
  "host" = "127.0.0.1",
  "port" = "5432",
  "keyring_label" = "mnmdb_temp",
  "connect_passwordless" = FALSE
)
