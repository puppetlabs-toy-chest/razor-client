# Razor Client Release Notes

## Next - Next

* BUGFIX: Fixed insecure flag when supplied in addition to a server URL.
* IMPROVEMENT: Proper short form argument style is now followed.
  Single-character arguments now require a single dash, e.g. `-c`.
* IMPROVEMENT: Error messaging for SSL issues has been improved.

## 1.1.0 - 2015-11-12

* IMPROVEMENT: By default, `razor` will point to port 8150.
* IMPROVEMENT: Better display of several views/collections.

## 1.0.0 - 2015-06-08

* NEW: Fit collection output to STDIN size for easier viewing.
* NEW: RAZOR_CA_FILE environment variable allows TLS/SSL certificate
  verification for requests.
* NEW: The default API protocol and port are HTTPS over TLS/SSL on port 8151.
* NEW: Utilizes `aliases` property in command metadata to better guess datatypes
  for aliases.
* IMPROVEMENT: `razor hooks` now displays as a table.
* IMPROVEMENT: Better output for `razor events ##`.
* IMPROVEMENT: Exits with an error code of 1 when a `razor` command fails.
* BUGFIX: `razor events` no longer causes exception.
* BUGFIX: `razor commands ## errors` no longer causes exception.
* BUGFIX: Hook output message can now be any datatype.

## 0.16.0 - 2015-01-05

* BUGFIX: Commands were not always including authentication
  information in every request.
* IMPROVEMENT: Ruby version compatibility: Now works with Ruby < 1.9.2.
* NEW: Separate API and CLI help examples: There are now two formats for help
  examples. The new CLI format shows help text as a standard razor-client
  command. CLI is used by default. The API format is the same as before,
  and will show examples in JSON format.
* NEW: The `events` collection is new and has a special client-side display.
* NEW: RAZOR_API and `razor -u $url` URLs need to be explicit about `http:` 
  and `https:`.
* NEW: Event queries can be limited (`razor events --limit 5`) and offset
  (`razor events --start 5`). This also works for `razor nodes $name log`.
* IMPROVEMENT: Viewing all columns in a query is now possible via 
  `razor $collection_path --full` rather than `razor --full $collection_path`.
* NEW: razor-client now has an 'insecure' flag to ignore SSL verification 
  errors.
* IMPROVEMENT: Argument types were previously not very context-aware. Now,
  for example, names can include the '=' character.
* BUGFIX: A reasonable error will be thrown if help is requested but does not exist.

## 0.15.1 - 2014-06-12

Server version compatibility

* It is highly recommended that razor-client version 0.15.x be used with
  razor-server version 0.15.x or higher.

## 0.15.0 - 2014-05-22

Usability of the client has been greatly enhanced:

* Tabular views of most collections: things like 'razor nodes' now display
  a table of results with important details about each node.
* Get help on commands via `razor help COMMAND`
* Output now includes hints on how to get more details on the things displayed
* No need to enter JSON on the command line for most commands (all but
  create-tag)
  + arrays can now be entered by repeating the same option, e.g. `razor
    create-tag --name ... --tag t1 --tag t2`
  + broker configuration is set using `razor create-broker --name
  .. --configuration var1=value1 --configuration var2=value2 ...`
* Clearer error message when server responds with 'Unauthorized'
  (RAZOR-175)
