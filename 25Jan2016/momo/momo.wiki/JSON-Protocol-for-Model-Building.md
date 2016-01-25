### TODO
1. Simulate failure scenarios to test error handling

### Overview

Once the end-user (in our case the analyst) uploads all the test/train images and pushes the "Build Model" button in the web UI, the build status of a model in the database is changed to "build-queue". At any given point, multiple models might be in the build queue. A model stays in the "build" state until its status is explicitly changed to "build-complete". The work-flow of taking the model from "build-queue" to "build-complete" is termed build task.

The communication protocol is modeled as API calls to the rails server. Prior to accessing any of the API calls, the back-end needs to authenticate itself with the rails server. Instructions on how to do this is found in "JSON Authentication" wiki. After authentication, the back-end will need to remember the token across URL requests.

The API calls are made by accessing specific URLs on the server using GET/PUT requests and passing JSON objects. Since the communication protocol is JSON, the URL request header needs to specify this.

After each API call, the server will respond with a JSON object. After a GET request, you'll receive what was requested and after PUT request, you'll receive a success/failure confirmation as "update_status" parameter. (See below for example)

To help debug the back-end communication module, every step in this document has a example using the command line "curl" utility. [Note: to remove clutter, all "auth-token" parameter have been removed from this document - however, it is assumed that the token is passed with each API request. Also all JSON requests in production should be sent as HTTPS and in development should be plain HTTP.]

### Connecting to the rails server

The rails server will be listening on specific port - 3000 for development and 80 (default internet) for production. For development following base URL is used `http://localhost:3000`

### Listing build tasks

All new build tasks automatically are in a "status" == "build-queue". [See status section below.] Accessing the following URL

`GET /builder/models`

returns a JSON with a list of models (parameters: id, name, algorithm) that correspond to build tasks that have yet to be built. Note that to keep track of multiple requests, all responses to GET request will include at least these fields.

JSON returned: Array of model parameters:

* id: Unique id of the model. There are no two models with the same id
* name: Name of the model. Non-unique
* algorithm: One of {MHMP, StructSVM, StructSVM-Generic}

Example: 

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/models`

_Returns:_

> [{"id":1,"algorithm":"StructSVM","name":"BeagleFront"},{"id":2,"algorithm":"StructSVM","name":"Sunset"}]

Note: This is an array of objects in JSON format.

### Accessing single build tasks

Individual build tasks can be accessed using following URL:

`GET /builder/models/modelId`

JSON returned:

* _in addition to model list params_
* status: Current status of the build task
* progress: Percentage completion of build task
* TRAIN_POS: Number of positive training images
* TRAIN_NEG: Number of negative training images
* TEST_POS: Number of positive testing images
* TEST_NEG: Number of negative testing images
* IMAGEBANK: Number of images in image bank

Example: 

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/models/1`

_Returns:_

> {"id":1,"name":"BeaglFront","algorithm":"StructSVM","status":"build-train-start","progress":"25","TRAIN_POS":15,"TRAIN_NEG":15,"TEST_POS":15,"TEST_NEG":15, "IMAGEBANK":300}

### Updating build status and progress

Prior to starting work on a build task, the build status for that task needs to be updated so that subsequent calls on `GET /builder/models` doesn't return that task as being in the build queue:

`PUT /builder/models/modelId`

with the "status" = "build-start".

Example: 

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"build-start"}' http://localhost:3000/builder/models/1`

_Returns:_

> {"update_status":"success"}

Once a task is removed from the build queue, the web UI will show a progress bar to indicate how far along the build process we are. Progress of the build process can be updated as follows:

`PUT /builder/models/modelId`

With JSON object of key "progress" and value between 0 and 100 - no percentage sign. It is recommended that progress largely depend on percentage of images/features that are downloaded and percentage of images whose feature has been computed. It is also recommended that this PUT happen at regular intervals, say every few minutes.

Example:

`curl -X PUT -H "Content-Type: application/json" -d '{"progress":"25"}' http://localhost:3000/builder/models/1`

_Returns:_

> {"update_status":"success"}

### Accessing image lists

Image lists for model training/testing can be obtained by calling following URL:

`GET /builder/models/modelId/album`

where "album" is one of the following:

* TRAIN_POS
* TRAIN_NEG
* TEST_POS
* TEST_NEG
* IMAGEBANK

JSON returned:

* _in addition to model list params_
* album: The type of album that was requested
* image id array: Array of ids of images that are needed to build/test the model.

Example:

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/models/1/TRAIN_POS`

_Returns:_

> {"id":1,"name":"BeagleFront","algorithm":"StructSVM","album":"TRAIN_POS","images":[{"id":15},{"id":14},{"id":13},{"id":12},{"id":11},{"id":10},{"id":9},{"id":8},{"id":7},{"id":6},{"id":5},{"id":4},{"id":3},{"id":2},{"id":1}]}

Note that because we could potentially have thousands of images in a single album, only the image-id is returned. S3 URL can be constructed from these image-ids as follows:

`s3ImageUrlString = concatenate('s3-us-west-2.amazonaws.com/zigvuimagesdevelopment/uploads/', imageId, '/original.png')`

If using the generic dictionary, it is recommended that the computed feature for each image be saved to the same folder using following S3 URL:

`s3GenericFeatureUrlString = concatenate('s3-us-west-2.amazonaws.com/zigvuimagesdevelopment/uploads/', imageId, '/generic.feat')`

Subsequently, if using the generic dictionary, it makes sense to check the existence of "generic.feat" and download that if it exists, prior to downloading the image. 

Note on current expectation of model-building algorithm:

1. All filenames are unique. Hence, as the images are downloading, they need to be renamed in the disk. Suggestion is to rename file as 1.png if imageId==1 and fileName==original.png.
2. StructSVM algorithm expects an image file to be present in a particular folder (even if the feature is already computed), and hence a `touch fileName.png` might be necessary if downloading pre-computed feature instead of file. All pre-computed features would go in a features directory - details can be seen in the algorithm code.

### Trained model file convention

Because different algorithm (current and future) produce different result files, the communication protocol shouldn't have to change with every new algorithm addition. Hence, a convention of storing files in specific location is proposed - the frontend always assumes that the built model files will be found in these locations. For example, for StructSVM, the "classes.txt" file is always to be found in the "models" folder for each object model. As long as the back-end saves the "classes.txt" in the same place for all models, the communication protocol can be agnostic to file locations.

Following steps need to take place after model building:

1. Put the built files in S3 bucket `zigvumodelsdevelopment` in a folder whose name is modelId.
2. Update current build task status to "build-train-complete". This status update essentially updates the S3 URLs for all model links in the database.

`PUT /builder/models/modelId`

with the "status" = "build-train-complete".

Example: 

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"build-train-complete"}' http://localhost:3000/builder/models/1`

_Returns:_

> {"update_status":"success"}

### Updating image detection scores - one by one

During the testing phase, each image is evaluated using the built model and a "score" is obtained. The obtained score can be relayed to the server by accessing URL:

`PUT /builder/models/modelId/updateScore`

with the "image_id" and "score" parameters in the JSON object. Note that "score" is expected to be a string that can be converted to a float. To ensure we are programming language agnostic, it is recommended that no scientific notation is used and a decimal point is always preceded by one or more digits. Valid: "0.00014". Invalid: ".34E-2".

Example: 

`curl -X PUT -H "Content-Type: application/json" -d '{"image_id":"1", "score":"0.071"}' http://localhost:3000/builder/models/1/updateScore`

_Returns:_

> {"update_status":"success"}

### Updating image detection scores - whole albums

Image scores can be updated in batches. For this, all images in an album need to be stored in S3 in JSON format as specified:

	{"ModelAlbumResult": {
			"ModelId": 20,
			"ModelVersion": 1,
			"ModelName": "Beagle",
			"Album": "TEST_POS",
			"Plugins": ["BlankScore", "BlurScore", "DetectionScore"],
			"ImageScores": [
				{"ImageId": 1, "BlankScore": 0.12, "BlurScore": 0.78, "DetectionScore": 0.73},
				{"ImageId": 12, "BlankScore": 0.22, "BlurScore": 0.63, "DetectionScore": 0.23}
			]
		}
	}


Note: The JSON keys should exactly match as described above - otherwise, rails will not update the scores.

This JSON file should be saved in S3 inside `uploads/modelId/` with a descriptive file name (e.g., `TEST_POS.results.json`. Once file is saved, a `PUT` call should be made to:

`PUT /builder/models/modelId/updateScoreFromFile`

with the "filename" parameter in the JSON object.

Example: 

`curl -X PUT -H "Content-Type: application/json" -d '{"filename":"TEST_POS.results.json"}' ` `http://localhost:3000/builder/models/1/updateScoreFromFile`

_Returns:_

> {"update_status":"success"}

Note: Only `DetectionScore` plugin is currently supported.

### Updating accuracy & threshold

Setting accuracy and threshold follows the same PUT pattern as seen in updating image scores. Instead of the image_id, we pass in the modelParam parameters (e.g., accuracy, threshold) we want to update and call following URL:

`PUT /builder/models/modelId/updateModelParam`

with a "modelParam:paramValue" JSON object. Note that "paramValue" is expected to be a string that can be converted to a float. To ensure we are programming language agnostic, it is recommended that no scientific notation is used and a decimal point is always preceded by one or more digits. Valid: "0.00014". Invalid: ".34E-2".

Currently supported modelParam are:
* accuracy - float value indicating accuracy of the model
* threshold - float value indicating threshold to bias the SVM decision boundary

Example: 

`curl -X PUT -H "Content-Type: application/json" -d '{"accuracy":"0.94"}' http://localhost:3000/builder/models/1/updateModelParam`

_Returns:_

> {"update_status":"success"}

### Status information

As already seen above, status information can be updated at any time by accessing following URL:

`PUT /builder/models/modelId`

With either "status" or "progress" JSON objects. Valid values for "status" are:
* "build-*" where * = one of {queue, start, initialize-instance, train-start, train-complete, test-start, test-complete, complete, shutdown-instance, failure}

Thus, build status can be one of:
* "build-queue" || "build-start" || "build-initialize-instance" || "build-train-start" || "build-train-complete" || "build-test-start" || "build-test-complete" || "build-complete" || "build-shutdown-instance" || "build-failure"

Look at the failure handling section for further discussion on "status" == "build-failure". 

Upon "status" == "build-complete" or "build-failure", it is assumed that the client dies so further server response is not guaranteed.

The most recently set status and progress can be accessed with a GET request as already shown above:

`GET /builder/models/modelId`

It is recommended that for each state change, the status update information be sent to the server so that the web UI can display it.


### Failure handling

A status="build-failure" can be issued at any time during the model building process. This failure could be due to a software bug or could be because of a lack of resources (e.g., spot instance crash.) The back-end is expected to notify rails of the error by accessing the following URL:

`PUT /builder/models/modelId`

With following parameters:

* status: "build-failure"
* error: string explaining type of error (Note: due to limit on `PUT` string length, this needs to be less than 1K characters)

Example:

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"build-failure", "error":"Spot instance crash"}'` `http://localhost:3000/builder/models/3`

_Returns:_

> {"update_status":"success"}

Upon successful update of database with the error message, a "success" is returned by the rails server. If the build failure occurs after model files have been saved in S3, it is recommended that they be deleted prior to sending the "build-failure" notification to rails.

To help debug failure cases, all failure cases are currently shown to the end-user in an admin interface. The model build task can be "reset" to run again from the admin interface. Upon reset, rails will clean up all scores for this model and put it back in the build queue.

