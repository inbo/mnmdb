#!usr/bin/env Rscript

keyring_label <- "mnmdb_temp' && echo 'this is a test'"
if (!(keyring_label %in% keyring::keyring_list()$keyring)) {
  init_keyring(keyring_label)
}

# use the `seahorse` util to double check
keyring_label <- "mnmdb_temp"
if (!(keyring_label %in% keyring::keyring_list()$keyring)) {
  init_keyring(keyring_label)
}
terminate_keyring(keyring_label)

lock_keyring_delayed(keyring_label = keyring_label, delay = 5)

unlock_keyring(keyring_label)



keyring::key_set_with_value(
  service = "mnmdb_credentials",
  username = "tester",
  keyring = keyring_label,
  password = getPass::getPass("Test password: ")
)


existing <- keyring::key_list(keyring = "mnmdb_temp")
# existing_user <- existing$username == "tester3"


