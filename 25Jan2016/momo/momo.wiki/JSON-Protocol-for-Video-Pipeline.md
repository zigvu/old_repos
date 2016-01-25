### TODO
1. Simulate failure scenarios to test error handling

### Overview

After a model is built, it can be evaluated against one or more videos. This document describes the communication protocol between the rails server and back-end scripts for the video pipeline which has following steps:

1. End-user uploads a video from desktop or through a URL
2. Video is saved in S3 and meta-data on the video is passed on to rails server
3. End-user tags videos as having specific objects, scenes or activities
4. End-user specifies which models should be evaluated against which videos
5. Once the models have been evaluated, the result is aggregated and presented to end user
6. End-user can browse the evaluated {video, model} pairs and copy/paste video frames to build new models

This document describes the communication protocol between the rails server and back-end scripts for the video pipeline.

The communication protocol is modeled as API calls to the rails server. Prior to accessing any of the API calls, the back-end needs to authenticate itself with the rails server. Instructions on how to do this is found in "JSON Authentication" wiki. After authentication, the back-end will need to remember the token across URL requests.

The API calls are made by accessing specific URLs on the server using GET/PUT requests and passing JSON objects. Since the communication protocol is JSON, the URL request header needs to specify this.

After each API call, the server will respond with a JSON object. After a GET request, you'll receive what was requested and after PUT request, you'll receive a success/failure confirmation as "update_status" parameter. (See below for example)

To help debug the back-end communication module, every step in this document has a example using the command line "curl" utility. [Note: to remove clutter, all "auth-token" parameter have been removed from this document - however, it is assumed that the token is passed with each API request. Also all JSON requests in production should be sent as HTTPS and in development should be plain HTTP.]

### Connecting to the rails server

The rails server will be listening on specific port - 3000 for development and 80 (default internet) for production. For development following base URL is used `http://localhost:3000`

### Listing all video tasks

The main tasks that require input from back-end are:

* Uploading a video file from a given URL
* Inspecting a previously uploaded S3 video to gather meta-data
* Evaluating one or more models against a particular video

Each task has four "states" associated with it: "queue", "current", "success" and "failure". When the end-user requests a task, the task state is changed to a "queue". Once the back-end can serve an element in this queue, its state should be changed to "current". Upon completion of the task, a "success" or "failure" is expected for the task.

Accessing the following URL

`GET /builder/videos`

returns a JSON with a list of videos (parameters: id, task) that have associated video tasks. Note that to keep track of multiple requests, all responses to GET request will include at least these fields.

JSON returned: Array of video tasks:

* id: Unique id of the video. There are no two videos with the same id
* task: One of {"upload-queue", "inspect-queue", "evaluate-queue"}

Example: 

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/videos`

_Returns:_

> [{"id":1,"videotask":"upload-queue"},{"id":2,"videotask":"inspect-queue"},{"id":3,"videotask":"evaluate-queue"}]

Note: This is an array of objects in JSON format.

Since the syntax for failure cases is the same, all failure cases are explained at the bottom of the document.

### Uploading a single video

Currently, two upload methods are supported: upload from desktop and upload from URL. For upload from desktop, the back-end is not involved. For upload from URL, only "youtube" URL is supported. Individual upload video tasks can be accessed by:

`GET /builder/videos/videoId/upload`

This returns a JSON object with following parameters:

* _in addition to video task params_
* source_type: for now, only "youtube" is supported
* file_source: URL for the video page

Example: 

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/videos/1/upload`

_Returns:_

> {"id":1,"source_type":"youtube","file_source":"http://www.youtube.com/watch?v=vpAsZXlpxsY","videotask":"upload-queue"}

Once ready to download a video from youtube (for uploading to S3), a PUT request with status "upload-current" should be made to:

`PUT /builder/videos/videoId/upload`

so that the video task state can be updated for the end-user.

Example:

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"upload-current"}'` `http://localhost:3000/builder/videos/1/upload`

_Returns:_

> {"update_status":"success"}

We can use youtube-dl (already installed in ModelBuilder instance) to download videos from youtube:

`youtube-dl -t -c --write-info-json --max-quality url <file_source>`

Once the file has been downloaded using the above command, it needs to be saved in S3 in `zigvuvideosdevelopment` bucket and `uploads/videoId` folder with the name `original.xxx` where 'xxx' is the video file format extension. The folder "videoId" doesn't exist yet, so that will need to be created as well. The "--write-info-json" also dumps some meta-data about the video that we'll use in the next section.

Once the video has been uploaded to S3, a "upload-success" needs to be PUT to:

`PUT /builder/videos/videoId/upload`

with the following JSON object:

* status: "upload-success"
* S3_URL: URL of the recently saved video

Example: (replace S3_URL with actual URL for the example to work)

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"upload-success", "S3_URL":"fullHTTPURLtoS3"}'` `http://localhost:3000/builder/videos/1/upload`

_Returns:_

> {"update_status":"success"}

Before the rails server sends the "update_status" as "success" it puts the video in "inspect-queue" so that meta-data can be extracted and sent to rails. Hence, as soon as you receive "success" return status, you can start the inspect process as described in the next section.


### Inspecting a single video

To show video meta-data information to the end-user, a video needs to be "inspected" using FFMPEG. An inspect task can be used by accessing the following URL

`GET /builder/videos/videoId/inspect`

returns a JSON object with following parameters:

* _in addition to video task params_
* S3_URL: URL where the video file is stored in S3.

Example:

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/videos/2/inspect`

_Returns:_

> {"id":2,"S3_URL":"fullHTTPURLtoS3","videotask":"inspect-queue"}

All video files are saved in S3 in `zigvuvideosdevelopment` bucket and `uploads/videoId` folder with the name `original.xxx` where 'xxx' is the video file format extension. Once ready to inspect a video, a PUT request with status "inspect-current" should be made to:

`PUT /builder/videos/videoId/inspect`

so that the video task state is updated for the end-user.

Example:

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"inspect-current"}'` `http://localhost:3000/builder/videos/2/inspect`

_Returns:_

> {"update_status":"success"}

For inspecting a video, meta-data needs to be extracted using FFMPEG and sent to the rails server. Once the meta-data has been extracted, a PUT request needs to be made to the URL:

`PUT /builder/videos/videoId/inspect`

with the following JSON object:

* status: "inspect-success"
* quality: one of {"1080P", "720P", "480", "HIGH", "MEDIUM", "LOW", "UNKNOWN"} - use high/medium/low only if other description not available
* videoformat: the format of the video (e.g., mp4, flv)
* length: length of video in milliseconds - expect integer only
* size: file size in bytes - expect integer only
* title: title as given in website - you get this from youtube-dl JSON dump, else "none"
* description: description as given in website - you get this from youtube-dl JSON dump, else "none"

Example:

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"inspect-success", "quality":"1080P", "videoformat":"mp4",` `"length":"1442", "size":"58", "title":"none", "description":"none"}'` `http://localhost:3000/builder/videos/2/inspect`

_Returns:_

> {"update_status":"success"}


### Accessing single video information

All saved information about a video can be accessed using following URL:

`GET /builder/videos/videoId`

JSON returned:

* _all video list params_
* _all upload-success params_
* _all inspect-success params_

Example: 

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/videos/2`

_Returns:_

> {"id":1,"videotask":"upload","source_type":"youtube","file_source":"http://www.youtube.com/watch?v=vpAsZXlpxsY","S3_URL":"fullHTTPURLtoS3","quality":"1080P","format":"json","length":1442,"size":58,"title":"Some Youtube Title","description":"Some Youtube Description"}


### Evaluating a single video - multiple models

Once a video is uploaded, the end-user will decide which models, if any, the video will be evaluated against. The user can put the video in an evaluation queue and if task status hasn't been updated to "evaluate-current", the video can also be removed from the queue. It can be safely assumed that all accessible models have already been built.

Video evaluation tasks can be accessed by:

`GET /builder/videos/videoId/evaluate`

This returns a JSON object with following parameters:

* _in addition to video task params_
* models: an array of modelId of models to be evaluated against

Example: 

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/videos/3/evaluate`

_Returns:_

> {"id":3,"videotask":"evaluate-queue","models":[{"id":1},{"id":2}]}


### Evaluating a single video - single model

Since frame extraction and feature computation is the most expensive part of evaluation, it is expected that extracted frame and subsequent feature computation is shared across models. However, this sharing is transparent to the rails server. Since the server is only storing pointers, it treats each evaluation task as being of a {video, model} pair. That is, if there are ten models to be evaluated against a video, the rails server will maintain ten different set of transactions for the evaluation.

Accessing a single {video, model} pair evaluation task is through URL:

`GET /builder/videos/videoId/evaluate/modelId`

This returns a JSON object with following parameters:

* _in addition to video task params_
* model: parameters that are supplied are {id, name, algorithm}

Description of model parameters:
* id: ID of current model - used to access model files from `zigvumodelsdevelopment`
* name: name of current model
* algorithm: algorithm used to build the model

Example: 

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/videos/3/evaluate/1`

_Returns:_

> {"id":3,"videotask":"evaluate-queue","model":{"id":1,"algorithm":"StructSVM-Generic","name":"Beagle"}}

If the end-user has taken the model detection out of the queue in the interim, then, a failure is returned instead:

_Returns:_

> {"update_status":"failure: model is not in evaluation state"}

A {video, model} pair evaluation requires following steps:

1. Indicate {video, model} pair is ready to be processed
2. Frame extraction, feature computation and actual detection
3. Saving frame to S3 for end-user reference
4. Updating rails on frame processing
5. Updating rails on video level classification (upon full video scanning or early finish)

Note that for steps 1, 4 and 5, back-end needs to communicate with rails. These steps are described below.

#### Indicate {video, model} pair is ready to be processed

Once ready to evaluate a {video, model} pair, a PUT request with status "evaluate-current" should be made to:

`PUT /builder/videos/videoId/evaluate/modelId`

so that the end-user is informed of current evaluation.

Example:

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"evaluate-current"}'` `http://localhost:3000/builder/videos/3/evaluate/1`

_Returns:_

> {"update_status":"success"}

Note that once all queued models for this video have been assigned to "evaluate-current" state, then the whole video is transitioned from "evaluate-queue" to "evaluate-current" state. Also, as before, if there is a race condition and the end-user takes this model evaluation out of the the queue, a failure is indicated. All further processing for this {video, model} pair can be stopped at this time. However, if rails respond with "success", the user is not allowed to take this {video, model} pair out of the queue any more.

#### Get length of video in queue

To get the total length of video that need processing, a `GET` request to following URL can be made:

`GET /builder/videos/evaluateQueueLength`

This returns the sum of length of all videos in "evaluate-queue" and "evaluate-current" state. The unit of return value is milliseconds. If there are no videos in queue, this call will return a length of zero.

Example:

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/videos/evaluateQueueLength`

_Returns:_

> {"evaluate_queue_length":6402}

In case the length of video was not properly populated during "inspect-success", a failure is reported:

> {"status":"failure: length of at least one video is nil"}

#### Updating rails on frame processing - one by one

During a typical {video, model} pair evaluation task, a frame is extracted at regular intervals and is run through the model. The resulting classification score dictates which next frame, if any, needs to be extracted and evaluated. (This is the sliding window we have been using.) To propagate classification scores across time, we might use a decay function to transform current classification score. Such transformed score gives us a sense of a "cumulative" score of the video which when above a certain threshold indicates that the whole video is positive/negative w.r.t. that model.

When a frame is extracted and evaluated, a PUT request needs to be made to:

`PUT /builder/videos/videoId/evaluate/modelId/videoframe`

with the following JSON

* frame_position: timestamp of this frame as number of milliseconds since start of video (integer)
* S3_URL: full URL of where this image is saved in S3
* frame_score: classification score of the current frame (float value)
* cumulative_score: transformed score of current frame that takes into account previous frame detections; for now, set equal to (frame_score + 0.1) (float value)
* classification: one of {"positive", "negative"} - to be extended in future

Note that the rails server is agnostic to the S3_URL generated. Evaluation of {video, model_1}..{video, model_n} will require evaluating a lot of common frames. Saving these frames and associated extracted features will save us computation time, and potentially storage space (by removing duplicate frames from S3). The back-end has complete autonomy on how to extract frames, where to store them and what to do with extracted features. However, in keeping in line with our naming conventions, it is recommended that frames be saved under `videoId/frames/timestamp` folder with `original.png` file name. If features are also saved, they can be saved under `videoId/frames/timestamp` folder with `generic.feat` file name.

Example:

`curl -X PUT -H "Content-Type: application/json" -d '{"frame_position":889, "S3_URL":"fullHTTPURLtoS3", "frame_score":0.0132,` `"cumulative_score":0.324, "classification":"positive"}' http://localhost:3000/builder/videos/3/evaluate/1/videoframe`

_Returns:_

> {"update_status":"success"}

If for some reason the database update doesn't happen (e.g., if the model has already been evaluated on that particular frame), a failure message is sent back.

To query the rails server if a frame has been previously extracted, a GET request can be sent to:

`GET /builder/videos/videoId/evaluate/modelId/videoframe/frame_position`

where <frame_position> indicates the number of milliseconds (integer) from start of video where the frame is located. If rails finds the previously saved file, it will return a JSON with:

* _in addition to video task params_
* _in addition to model params_
* videoframe: {id, S3_URL} where:
* id: id of the video frame
* S3_URL: url of the previously extracted frame

Example:

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/videos/3/evaluate/1/videoframe/889`

_Returns:_

> {"id":3,"videotask":"evaluate-queue","model":{"id":1,"algorithm":"StructSVM-Generic","name":"Kitchen"},"videoframe":{"id":2,"S3_URL":"fullHTTPURLtoS3"}}


If no frame exists, a failure is returned instead.

Example:

`curl -X GET -H "Content-Type: application/json" http://localhost:3000/builder/videos/3/evaluate/1/videoframe/890`

_Returns:_

> {"update_status":"failure: frame does not exist"}

#### Updating rails on frame processing - whole video

Video frame scores can be updated in batches. For this, all video frames need to be evaluated with all models and results stored in S3 in JSON format as specified:

	{"VideoEvaluationResult": {
			"VideoId": 2,
			"ModelIds": [2, 3, 5],
			"Plugins": ["BlankScore", "BlurScore", "DetectionScore"],
			"VideoFrames" : [
				{"VideoFrameNumber": 15, "S3_URL":"http://someS3_15.url.png", "FrameType": "Scan", "BlankScore": 0.12, "BlurScore": 0.78, "DetectionScores":[
					{"modelId": 2, "DetectionScore": null},
					{"modelId": 3, "DetectionScore": null},
					{"modelId": 5, "DetectionScore": null}
					]},
				{"VideoFrameNumber": 16, "S3_URL":"http://someS3_16.url.png", "FrameType": "Window", "BlankScore": 0.22, "BlurScore": 0.63, "DetectionScores":[
					{"modelId": 2, "DetectionScore": null},
					{"modelId": 3, "DetectionScore": 0.3},
					{"modelId": 5, "DetectionScore": null}
					]}
			]
		}
	}

Note: The JSON keys should exactly match as described above - otherwise, rails will not update the scores.

This JSON file should be saved in S3 inside `uploads/videoId/` with a descriptive file name (e.g., `21Jan2014_4PM.json`) that will not conflict with future evaluations on the same video. Once file is saved, a `PUT` call should be made to:

`PUT /builder/videos/videoId/evaluateUpdateFromFile`

with the "filename" parameter in the JSON object.

Example: 

`curl -X PUT -H "Content-Type: application/json" -d '{"filename":"21Jan2014_4PM.json"}' ` `http://localhost:3000/builder/videos/videoId/evaluateUpdateFromFile`

_Returns:_

> {"update_status":"success"}

Note: Only `DetectionScore` plugin is currently supported. `FrameType` is NOT supported but `VideoFrameNumber` and `S3_URL` are both required.


#### Updating rails on video level classification

Once all frames have been analyzed, back-end needs to send a video-level classification for the {video, model} pair by using following URL:

`PUT /builder/videos/videoId/evaluate/modelId`

with the following JSON

* status: "evaluate-success"
* score: final video classification score; for now, indicate 1 for +ve and 0 for -ve (float)
* classification: one of {"positive", "negative"}

Example:

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"evaluate-success", "score":0.0132, "classification":"positive"}'` `http://localhost:3000/builder/videos/3/evaluate/1`

_Returns:_

> {"update_status":"success"}

When all queued models in the video task are evaluated, i.e., when {video, model_1}..{video, model_n} tasks are all evaluated and if the user hasn't added any more models to the evaluation queue, then the status of video evaluation is automatically set to "evaluate-success".

### Failure handling

For each of the three tasks (upload, inspect, evaluate), there is a "failure" state that indicates that some error has occurred during processing of that task. This error could be due to a software bug or could be because of a lack of resources (e.g., spot instance crash.) The back-end is expected to notify rails of the error using the same `PUT` URL as in the case of success. Following JSON should be supplied:

* status: "*-failure" where * = one of {upload, inspect, evaluate}
* error: string explaining type of error (Note: due to limit on `PUT` string length, this needs to be less than 1K characters)

For example, in the case of a failure in {video, model} pair evaluation, a status: "evaluate-failure" needs to be `PUT` to the same address as in the case of success:

`curl -X PUT -H "Content-Type: application/json" -d '{"status":"evaluate-failure", "error":"Spot instance crash"}'` `http://localhost:3000/builder/videos/3/evaluate/1`

_Returns:_

> {"update_status":"success"}

Upon successful update of database with the error message, a "success" is returned by the rails server.

To help debug failure cases, all failure cases are currently shown to the end-user in an admin interface. Until the end-user acknowledges the errors, no new video task will be allowed for that video. The video task can be "reset" to run again from the admin interface.

Additionally, following cleanup steps are required from the backend in failure cases:

#### Failure in video upload

* Delete `video_id` folder in S3 prior to sending failure notice. No change in database yet, so changing only upload state is sufficient.

#### Failure in video inspect

* None. No change in database yet, so changing only inspect state is sufficient.

#### Failure in {model, video} evaluation

* None. Rails will delete all orphaned video frames from S3 and reset all incomplete frame detections for this {model, video} pair. 

Note that other {model, video} pairs which have already been transitioned to "evaluate-current" state are allowed to complete the evaluations but {model, video} pairs which are still in "evaluate-queue" state are not allowed to be taken to the "evaluate-current" state. Once the admin resets the failed {model, video} pair, all "evaluate-queue" state {model, video} pairs are visible and can be transitioned into "evaluate-current" state. To avoid race conditions, it is recommended that prior to starting any lengthy process, a `GET` call to appropriate URL be made to ensure that video task queues have not changed since the last `GET`.


