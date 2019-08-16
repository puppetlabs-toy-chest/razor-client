# Razor Client Release Notes

## 1.9.3 - 2019-08-19

* BUGFIX: The `unf` gem dependency referenced a prerelease version of a gem.
  Rather than force the use of `--pre` when installing the gem, we will pin
  back to the released version, which requires GCC to build native extensions.

## 1.9.2 - 2019-08-14 (yanked)

* BUGFIX: Fixed error output when number or null datatypes are invalid.
* IMPROVEMENT: Now exits with status code 1 if login credentials are missing.
* IMPROVEMENT: Updated gem dependencies.
* IMPROVEMENT: Better error handling for REST exceptions returned from the
  Razor server.
* IMPROVEMENT: Removed Gemfile.lock from repository. This broadens the spectrum
  of which gems can be used as dependencies for this gem. This is especially
  useful for gem dependencies that become outdated or obsolete.
* BUGFIX: Pinned a version of the `gettext-setup` gem which caused an error if
  the version was too old.

## 1.9.1 - 2018-06-07

* NEW: Use the server's `depth` parameter if it is supported. This will
  dramatically decrease the number of API requests needed when listing
  collections.

## 1.8.1 - 2018-04-23

* IMPROVEMENT: The default API URL now attempts to use TLS on localhost port
  8151 before falling back to non-TLS on 8150.
* BUGFIX: Removed extra output that was being added.

## 1.8.0

* IMPROVEMENT: Now allowing underscores to be mixed into argument lists,
  e.g. `razor create-broker --name test --broker_type noop`
* BUGFIX: Fixed extra output that was being added.

## 1.7.0 - 2018-01-17

* NEW: Removed support for Ruby < 2.0
* BUGFIX: Removed security vulnerabilities in gems

## 1.4.0 - 2017-03-07

* Added support for internationalization by setting the Accept-Language
  header for API requests.

## 1.3.0 - 2016-05-19

* NEW: Added elegant display of the `razor config` collection.
* IMPROVEMENT: Individual properties in collections can now be scoped.
  Previously, only arrays and objects were allowed, now you can find
  a single value.

## 1.2.0 - 2016-03-08

* BUGFIX: Razor client version will be reported even if the Razor server is
  unreachable.
* BUGFIX: Fixed insecure flag when supplied in addition to a server URL.
* NEW: Added positional argument support, when supplied by the server. See
  `razor <command> --help` for details on usage.
* NEW: Added USAGE section to the command's help, which will include positional
  arguments, if any exist.
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
