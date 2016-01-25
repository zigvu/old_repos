### Overview

To secure API requests, it is now necessary to "sign-in" using a pre-assigned username/password. Upon successful sign-in, an authentication token will be provided for subsequent API access. This authentication token will be required for all API access. If the authentication token is incorrect or has expired (due to a timeout), the API request will fail. Once all tasks are complete, the back-end needs to "sign-out" to limit non-authenticated users from accessing the API.

This document describes the communication protocol between the rails server and back-end scripts for authentication.

To help debug the back-end communication module, every step in this document has a example using the command line "curl" utility. Also all JSON requests in production should be sent as HTTPS and in development should be plain HTTP. [Note: To use CURL in HTTPS, it might be necessary to ignore certificate authenticity with a `--insecure` flag.]

### Signing in

To sign-in, the back-end needs to POST credentials to the following URL:

`POST /users/sign_in`

with following JSON parameters:

* username: [hidden, sent in email]
* password: [hidden, sent in email]

Upon successful sign-in, following JSON is returned:

* username: the user who is currently signed in
* success: true (boolean)
* auth_token: authentication token to be used in subsequent API access (string)

Example: 

`curl -X POST -H "Content-Type: application/json" -d '{"username":"hidden", "password":"hidden"}' http://localhost:3000/users/sign_in`

_Returns:_

> {"success":true,"auth_token":"mJkmudTdjm6sxbVgnXqG","username":"hidden"}

Note that the received authentication token will be valid until:

* it expires due to timeout (currently no timeout set)
* user signs out

As long as the token is valid, subsequent POST to sign_in will return the same token.

Note: It is recommended that the "hidden" username/password be set as environment variable in the Ubuntu machine and be accessed from the python library when needed. This is apparently the best practice to allow clear-text password for automated API calls. If security becomes a big concern, we can address this further with on-demand encryption/decryption of the environment variable.

### Signing out

To sign-out, the back-end needs to send DELETE to the following URL:

`DELETE /users/sign_out`

with following JSON parameters:

* username: [hidden, sent in email]

Upon successful sign-out, following JSON is returned:

* success: true (boolean)

Example: 

`curl -X DELETE -H "Content-Type: application/json" -d '{"username":"hidden"}' http://localhost:3000/users/sign_out`

_Returns:_

> {"success":true}

Note that prior authentication token will no longer be valid.

### Accessing tasks

Once authenticated, all tasks need to append following parameter to their regular JSON object:

* auth_token: authentication token received after sign-in

Example:

`curl -X GET -H "Content-Type: application/json" -d '{"auth_token":"wruCzwHvjHPkQc4AGsQ9"}' http://localhost:3000/builder/videos`

_Returns:_

> [{"id":1,"videotask":"evaluate-queue"}]

If the authentication token is invalid, it instead returns:

> {"error":"Invalid authentication token."}

