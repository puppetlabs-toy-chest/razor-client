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