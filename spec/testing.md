For developers:

Client-side spec tests use a framework called VCR for testing the client independent of the server. VCR fakes the
interactions from the server so the client can continue executing its code. It does this by copying the exact
expected input, then replying with the response provided by the server when the test is executed in a "record" mode.

When writing these tests, keep in mind that other developers may need to rerecord tests. This can occur if a
request to the server is somehow different, or if the client needs to issue a new request to the server.

Here are some suggestions to make rerecording easier:

- If a request has external dependencies, set up the dependencies as part of (or before) the test.
    - For example, let's say you're testing the `create-policy` command. Execution of that command requires several
      objects be present in the database: brokers, repos, etc. The only way to issue the `create-policy` command
      successfully on the client is to issue `create-broker`, `create-repo`, etc. beforehand. These extra commands
      should be part of the test.
- Ensure authentication is disabled on the razor-server torquebox instance. A GET of http://localhost:8150/api
  should return the API.

When recording VCR interactions, we need to reset the database between each test so that we can ensure test isolation.
The tests here assume a directory structure like this (defined in `spec_helper.rb`), which allows our tests to reset
the database back to an empty state between tests:
- Parent directory
-- razor-client
--- ...
-- razor-server
--- bin/razor-admin
--- ...

Thus, to run `razor-admin`, recording VCR interactions must be done with JRuby, specifically the version matching
razor-server.

If your filesystem directory matches the above, and you're ready to start recording a test, run torquebox from the
razor-server directory in one terminal window as so:

`torquebox run -b 0.0.0.0 --port 8150`

Then run the tests tagged with `:vcr` using the `VCR_RECORD` prefix:

`VCR_RECORD=all bundle exec rspec spec -t vcr`

See [VCR's documentation](https://relishapp.com/vcr/vcr/docs) for other available VCR modes.
