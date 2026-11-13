library("mnmdb")
library("dplyr")
library("sf")

auth <- mnmdb::mnmdbAuthConf(
    config_file = file.path("config_files", "mnmgwdb.conf"),
    connect_passwordless = TRUE,
    database = "mnmsurfdb"
  )
describe(auth)

mnmdbconn <- mnmdb::mnmdbConnection(
    auth = mnmdb::mnmdbAuthConf(
      config_file = file.path("config_files", "mnmgwdb.conf"),
      connect_passwordless = TRUE
    )
  )
mnmdb::describe(mnmdbconn)

# connect
mnmdbconn <- mnmdbconn |> mnmdb::connect()
mnmdb::describe(mnmdbconn)

# query all
all_locations <- mnmdbconn |> query_table(DBI::Id("metadata", "Locations"))

all_locations$geometry <- sf::st_as_sfc(structure(as.list(all_locations$wkb_geometry), class = "WKB"), EWKB=TRUE )
all_locations <- sf::st_as_sf(all_locations)

all_locations %>% glimpse()


# filter
grts_list <- c(
  48897,
  454998,
  681846,
  759262,
  857769,
  1304366,
  1639134,
  1770206,
  1806302,
  2468398,
  2605790,
  2623314,
  3113917,
  3234802,
  3447598,
  3598062,
  3648158,
  3901714,
  5465974,
  6033970,
  6757102,
  8005938,
  8578898,
  9321121,
  10770158,
  20774622,
  50260274,
  20807190,
  33958194,
  46780406,
  47868210,
  50064118,
  50909490,
  51263134,
  53516150,
  54531374,
  55458526,
  55700526,
  222878,
  231150,
  617774,
  762158,
  906654,
  1012434,
  1239346,
  1675858,
  1988334,
  2025778,
  2333486,
  3514038,
  7006514,
  9883950,
  19205238,
  50634422,
  14026450,
  22021842,
  572349,
  902185,
  2393618,
  7244918,
  10211046,
  255241,
  377138,
  812918,
  1382706,
  1386153,
  1537582,
  2248694,
  2581814,
  3764918,
  4358630,
  8984882,
  10991922,
  197342,
  301614,
  501982,
  1120478,
  1284318,
  1554390,
  1685462,
  1736414,
  1823954,
  2084574,
  2606838,
  2814902,
  2977246,
  7545533,
  218158,
  529234,
  3416878,
  4911805,
  2258078,
  452054,
  452914,
  602258,
  687846,
  842210,
  893046,
  1999154,
  2150070,
  2492114,
  7856546,
  10907414,
  12420626
)


selected_locations <- all_locations %>% filter(
    grts_address %in% grts_list
  )

# check
if (nrow(selected_locations) == length(grts_list)) {
  message("number of locations match!")
} else {
  missing_locations <- all_locations %>%
    mutate(
      found = grts_address %in% grts_list
    ) %>%
    filter_out(found)
  stop("The above GRTS addresses were not found!")

}

# inspect
selected_locations %>% glimpse()

mapview::mapview(selected_locations)


sf::st_write(selected_locations,
  dsn = "./locaties_2027_preview.gpkg",
  layer = "Overzicht finale locaties",
  append = FALSE
  )
