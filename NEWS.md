# Razor Client Release Notes

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
