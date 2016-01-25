### Overview

To detect scenes (e.g., Kitchen), we build multiple structSVM models (e.g., sink, microwave, cooking) that describe components of the scene we want to detect. The prediction of these structSVM models are then combined using libSVM algorithm to create a meta-classifier that classifies kitchens. The process of going from stand-alone structSVM models to the combined libSVM models is termed the "release" process. This document describes (1) the user interface for the release process and (2) the builder interface to build releases.

### Creating a new release

After a set of structSVM models have been built, we can start building a new release. Currently, only admins can create a release. 

structSVM models are all created in a tree hierarchy. Different version of a structSVM model (e.g., sink:v1, sink:v2) all have the same node (also named sink) in the tree hierarchy. Moreover, for each vertical, the meta-classifiers (e.g., libsvm model that outputs kitchen) are also organized in a tree. When we create a release, we need to specify at what level in the tree hierarchy we want to aggregate structSVM models.

Following rules need to be satisfied before a release is accepted for building:

1. The root of the structSVM tree cannot be a release node
2. At least two nodes must be marked as released
3. The weak model node must be marked as released
4. Two versions of a model cannot be marked for release
5. Each released node must have at least 1 model present
6. A node that is released can not be a descendent of another node that is also released
7. A model that is selected for release must have at least 1 ancestor node that is released

### Building a release

Once a release is accepted by the system, it can be built from the UI by pressing the "Build" button. The system creates following files in the release S3 bucket under `uploads/releaseId/input` where `releaseId` refers to the database ID of the release:

1. mapping.txt - a JSON file with the ID, name and tree hierarchy of released structSVM models.
2. {nodeId.txt} - JSON files with the image IDs of each of the released nodes. There are multiple of these files present as dictated by `mapping.txt` file.

Once the files are saved in S3, the release is placed in a "build-queue" state. The build-cycle is the same as that for a structSVM model. For simplicity's sake, reporting build progress is not currently supported. A release stays in the "build" state until its status is explicitly changed to "build-complete".

The communication protocol is modeled as API calls to the rails server. Prior to accessing any of the API calls, the back-end needs to authenticate itself with the rails server. Instructions on how to do this is found in "JSON Authentication" wiki. After authentication, the back-end will need to remember the token across URL requests.

The API calls are made by accessing specific URLs on the server using GET/PUT requests and passing JSON objects. Since the communication protocol is JSON, the URL request header needs to specify this.

After each API call, the server will respond with a JSON object. After a GET request, you'll receive what was requested and after PUT request, you'll receive a success/failure confirmation as "update_status" parameter. (See below for example)

To help debug the back-end communication module, every step in this document has a example using the command line "curl" utility. [Note: to remove clutter, all "auth-token" parameter have been removed from this document - however, it is assumed that the token is passed with each API request. Also all JSON requests in production should be sent as HTTPS and in development should be plain HTTP.]

### Connecting to the rails server

The rails server will be listening on specific port - 3000 for development and 80 (default internet) for production. For development following base URL is used `http://localhost:3000`

### Listing build tasks

All new build tasks automatically are in a "status" == "build-queue". [See status section below.] Accessing the following URL

`GET /builder/releases`

returns a JSON with a list of releases (parameters: id, name, S3_URL) that correspond to build tasks that have yet to be built.

JSON returned: Array of release parameters:

* id: Unique id of the release. There are no two releases with the same id
* name: Name of the release. Non-unique
* S3_URL: The S3 location where the input files for the release are stored

Example: 

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/releases`

_Returns:_

> [{"id":1,"S3_URL":"uploads/1/input","name":"FirstKitchenRelease"},{"id":2,"S3_URL":"uploads/2/input","name":"SecondKitchenRelease"}]

Note: This is an array of objects in JSON format.

### Accessing single build tasks

Individual build tasks can be accessed using following URL:

`GET /builder/releases/releaseId`

JSON returned:

* content of the `mapping.txt` file

Example: 

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/releases/1`

_Returns:_

> [{"node_id":3,"node_name":"Dog","models":[{"model_id":9,"model_name":"Beagle","model_version":1}]},{"node_id":4,"node_name":"Airplane","models":[{"model_id":3,"model_name":"Airplane","model_version":0}]},{"node_id":9,"node_name":"TruckExtr","models":[{"model_id":8,"model_name":"TruckExtr","model_version":0}]},{"node_id":16,"node_name":"WEAKMODEL","models":[{"model_id":22,"model_name":"Animals_Air","model_version":0},{"model_id":23,"model_name":"Auto_Air","model_version":0}]}]

### Updating build status

Prior to starting work on a build task, the build status for that task needs to be updated so that subsequent calls on `GET /builder/releases` doesn't return that task as being in the build queue:

`PUT /builder/releases/releaseId`

with the "status" = "build-start".

Example: 

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"build-start"}' http://localhost:3000/builder/release/1`

_Returns:_

> {"update_status":"success"}

Once a task is removed from the build queue, the web UI will indicate that the build process has started. For now, progress is not reported and not shown in web UI.

### Accessing image lists

All image lists are accessed from S3 release bucket. For each release node, there is a file with `releaseId.txt` file name that contains the IDs of images to be used as positive example for that node in libsvm training. Please look at AWSCodebase wiki to find the required file format for input to libsvm.

### Status information

As already seen above, status information can be updated at any time by accessing following URL:

`PUT /builder/releases/releaseId`

Valid values for "status" are:
* "build-*" where * = one of {queue, start, initialize-instance, complete, shutdown-instance, failure}

Thus, build status can be one of:
* "build-queue" || "build-start" || "build-initialize-instance" || "build-complete" || "build-shutdown-instance" || "build-failure"

Look at the failure handling section for further discussion on "status" == "build-failure". 

Upon "status" == "build-complete" or "build-failure", it is assumed that the client dies so further server response is not guaranteed.

### Failure handling

A status="build-failure" can be issued at any time during the release building process. This failure could be due to a software bug or could be because of a lack of resources (e.g., spot instance crash.) The back-end is expected to notify rails of the error by accessing the following URL:

`PUT /builder/releases/releaseId`

With following parameters:

* status: "build-failure"
* error: string explaining type of error (Note: due to limit on `PUT` string length, this needs to be less than 1K characters)

Example:

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"build-failure", "error":"Spot instance crash"}'` `http://localhost:3000/builder/releases/3`

_Returns:_

> {"update_status":"success"}

Upon successful update of database with the error message, a "success" is returned by the rails server.

Currently, failure handling is not done in UI. If possible, a log of current execution should be updated to a S3 file in `uploads/releaseId/output` folder.
