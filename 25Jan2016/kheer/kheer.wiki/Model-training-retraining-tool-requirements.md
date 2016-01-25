### Guiding principles

A. Tool should be usable by entry-level analyst. Goal should be to abstract away implementation and execution details to the extent that tool feels like using any consumer oriented app (e.g., Facebook, Gmail).

B. Tool should handle large-scale data. Half a gigabyte of data (300MB of video and 200MB of annotation) wouldn't be unusual dataset for a day's worth of work for an analyst.

C. Tool should accommodate large number of users with different roles (e.g., entry-level analyst, senior analyst, manager).

D. Tool should be flexible to upgrades and customization.


## Kheer front-end API

This is a first draft of the API required to implement the model training/retraining parts in Kheer. This API is implementation technology agnostic but uses javascript terminologies (cause that's what's on my mind right now.) The API is also more of a long-term plan rather than immediate coding plan.

Note: For clarity, function calls are chained. In actual implementation, we might choose to break them apart.

### Application

In the `MVC` parlance, we can separate out our application thus:

	zApp = zigvu.application
		.dataManager(dataManager)            // model
		.filterHandler(filterHandler)        // controller
		.videoHandler(videoHandler)          // view (not directly seen by user)
		.frameDisplay(frameDisplay)          // view (seen by user)
		.chartManager(chartManager);         // view (seen by user)

where:

* `zigvu` : Global namespace for our code.
* `application`: The connecting glue to all of the application classes
* `dataManager(dataManager)`: Data manager - see description in _Data Management_ section
* `filterHandler(filterHandler)`: Filtering mechanism that dictates what filters to apply for this analysis. See section on _Data Filter_ for details.  Example: For each video, show 5 frames before and after every peak (e.g.: score > 0.8) of class `classId`
* `videoHandler(videoHandler)`: The video handling infrastructure - see description in _Video Handling_ section
* `frameDisplay(frameDisplay)`: The drawing of frame in screen and annotation on top - see description on _Frame Display_
* `chartManager(chartManager)`: The charting infrastructure - see description in _Chart_ section

### Video Handling

#### Create video handler

	zPlayer = zigvu.videoHandler
		.dataManager(dataManager)
		.filterHandler(filterHandler)
		.order(sequenceOrder)
		.heatmap(boolean);

* `videoHandler`: Object responsible for cutting and concatenating videos on the fly
* `dataManager(dataManager)`: The data manager
* `filterHandler(filterHandler)`: The filtering system
* `order(sequenceOrder)`: How each of the concatenated pieces of videos are ordered (e.g.: `score ASC`)
* `heatmap(boolean)`: If true, show heatmap - the class for heatmap is defined by `filterHandler`

#### Create a video player

	zPlayer = zigvu.videoHandler.player
		.buffer(numOfFrames);

* `player`: Player object that has video playback controls
* `buffer(numOfFrames)`: Number of frames to pre-compute when playing/seeking

#### Video navigation

Since frame operations are asynchronous, each navigation function takes a `callback` function that will be called after a canvas object for that frame can be extracted from zPlayer.

Playback calls:

* `zPlayer.play(callback)`: Play the video in sequence
* `zPlayer.pause(callback)`: Pause the video
* `zPlayer.fastForward(speed, callback)`: This is a convenience function for `zPlayer.seek` which seeks in forward direction
* `zPlayer.fastBackward(speed, callback)`: This is a convenience function for `zPlayer.seek` which seeks in forward direction

Frame level calls:

* `zPlayer.nextFrame(callback)`: Go to next frame in the player. Note: The next frame could be in another video
* `zPlayer.prevFrame(callback)`: Go to previous frame in the player. Note: The previous frame could be in another video
* `zPlayer.seek(videoId, timeStamp, callback)`: Seeks to given timeStamp in video with id `videoId`

#### Get frame image

	canvas = zPlayer.getCurrentCanvas();

### Frame Display

Annotations are drawn on top of the frame image gotten from zPlayer

#### Create a display

	frameDisplay = zigvu.frameDisplay
		.width(width)
		.height(height)
		.selector(selectorId)
		.dataManager(dataManager)
		.filterHandler(filterHandler)
		.annotations(boolean);

where:

* `frameDisplay`: Canvas object that has both display and drawing controls
* `width(width)`: Width of the canvas - this has to be the _SAME_ as video width
* `height(height)`: Height of the canvas - this has to be the _SAME_ as video height
* `selector(selectorId)`: Positioning of the canvas in the page
* `dataManager(dataManager)`: The data manager
* `filterHandler(filterHandler)`: The filtering system
* `annotations(boolean)`: If true, show/edit annotations - the `classIds` for annotations are defined by `filterHandler`

#### Create a drawing handler

A handler is needed for

* Drawing existing annotations
* Creating new annotations
* Modifying existing annotations

and

	zDrawingHandler = zigvu.frameDisplay.drawingHandler.
		isEditable(boolean);

where:

* `drawingHandler`: Object that handles UI interactions
* `isEditable(boolean)`: If true, will be able to add/edit annotations

#### Add existing annotations to display

After navigating to a new frame, we get a new frame image from video. Following calls add existing annotations on top of that canvas:

	frameDisplay
		.saveCurrent()
		.set(videoId, timeStamp)
		.setBackground(canvas);
	drawingHandler
		.removeAll()
		.addAnnotations();

where

* `frameDisplay.saveCurrent()`: Save current state of drawing. This is a `no-op` if no changes have been made to drawing
* `frameDisplay.set(videoId, timeStamp)`: Set the `videoId` and `timeStamp` to retrieve correct data from `dataManager`
* `frameDisplay.setBackground(canvas)`: Where `canvas` is `ImageData` we receive from `zPlayer.getCurrentCanvas()`
* `drawingHandler.removeAll()`: Remove all drawings from object
* `drawingHandler.addAnnotations()`: Add all annotations as specified by `filterHandler`

#### Update annotations

* `drawingHandler.select(annotationId)`: Select annotations based on user activity - `annotationId` is an internal pointer in `frameDisplay`
* `drawingHandler.removeSelected()`: Remove selected annotations
* `drawingHandler.addPoly(polygon, classId)`: Add selected polygon after error-check to annotation list. Assign new `annotationId` to the polygon and associate with `classId`

### Data Management

In a single run of the application (e.g., analysis to refine a model for a class), we will need:

1. Video data: Hundreds of MB of video data, potentially "quantized" into small chunks (e.g., 10 min long)
2. Frame data: Hundreds of MB of video processing data (chia results) as well as annotations from analysts

For a distributed system like we are building, most likely both of these data types will be stored in centralized server which would manage hundreds of GB of data. Upon request from application, these need to be streamed to analyst's machine and potentially stored there until the analysis is complete. "Streaming" these sources on demand on a per-frame basis is NOT an option - interactivity will suffer.

For the kheer front-end application, the current thinking is to load data in bulk during application initialization, store it in local cache (if using browser, in its `localDataStore`), and "stream" from that cache for filtering purposes. A `dataManager` object manages this local cache and is the conduit through which rest of the application sees the data

	zDataManager = zigvu.dataManager
		.persistentStorage(storage)
		.autoSynch(boolean);

* `dataManager`: Data object for handling both video and frame data (if using browser, video is stored in temp file system automatically)
* `persistentStorage(storage)`: The local cache to store data from server or data generated by user activity
* `autoSynch(boolean)`: If true, will synch to persistent storage after each change to in-memory data structures. If false, need to manually trigger synch

#### Persistent storage interface

Irrespective of the type of persistent storage, following operations will be needed:

* `dataManager.clearStorage(storage)`: Clear all data in `storage`
* `dataManager.addToStorage(storage, data)`: Add new data to storage
* `dataManager.synch()`: Update persistent storage with in-memory values (e.g., of new annotations)
* `dataManager.remoteSynch()`: Send any update on persistent storage to kheer server
* `dataManager.remoteGet()`: Get `data` from kheer server - for now, skip checking if this data has become stale

#### Read/update operations

We assume that all videos are processed through chia - hence, there is no new frame-level-data creation. We can only add/remove annotations

* `dataManager.getAnnotations(videoId, timeStamp)`: Get annotations associated with this video frame
* `dataManager.updateAnnotations(videoId, timeStamp)`: Update annotations associated with this video frame
* `dataManager.getClassScores(classId, videoId, timeStamp)`: Get scores of class elements for charts and heatmap
* `dataManager.getHistory(classId, videoId, timeStamp)`: Get the history associated with this `classId`/`videoId`/`timeStamp`
* `dataManager.getAll(videoId, timeStamp)`: Get the raw data dump for this frame
* `dataManager.getAll(videoId)`: Get the raw data dump for this video

#### Handling update history

To keep track of the work done by a particular analyst, it is important to keep track of update history of annotations. For example, if we want to only display those annotations which were incorrectly labeled by `chia` but correctly labeled by analyst, we need some history of annotations.

	zHistoryHandler = zigvu.dataManager.historyHandler
		.currentUserId(userId)
		.historyDepth(numOfRevisions);

where

* `historyHandler`: Keeps track of history of annotation changes based on `userId`
* `currentUserId(userId)`: User ID to associate with current revisions
* `historyDepth(numOfRevisions)`: Number of revisions to keep track

### Data filter

Charts are the filtering mechanism of reducing data overload. Our main goal is to discover "important" aspects of data interactively. Since we don't know what counts as "important", this section needs to be highly flexible and customizable.

	zFilterHandler = zigvu.filterHandler
		.videos(allVideoIds)
		.classes(allClassIds);

where

* `filterHandler`: Handles all filters
* `videos(allVideoIds)`: All videos for this analysis - will trigger download from server
* `classes(allClassIds)`: All classes for this analysis

#### Filtering

All objects that need to be aware of data filters should register with the `filterHandler` which will trigger a `callBack` function upon update of filter state.

	filterHandler.register(otherObject, callBack);

Following are some sample of filtering functions. These will be extended as and when need arises:

* `filterHandler.selectVideos([videoIds])`: Select a sub-set of `allVideoIds`
* `filterHandler.selectClasses([classIds])`: Select a sub-set of `allClassIds`
* `filterHandler.setScoreRange(scoreLowerBound, scoreUpperBound)`: Selector range for score
* `filterHandler.setBBoxWidthRange(widthLowerBound, widthUpperBound)`: Selector range for width
* `filterHandler.setBBoxHeightRange(heightLowerBound, heightUpperBound)`: Selector range for height
* `filterHandler.setMinimumDuration(classId, duration)`: Select only those frames for which classId is seen for minimum `duration` of time
* `filterHandler.setAnnotationUsers([userIds])`: Show only those annotations from particular users
* `filterHandler.selectExactFrames([{videoId:, timeStamps: []}, ])`: Select frames from different videos, e.g., after scatter plot selection

### Charts

Any selection element (e.g., a checkbox, scatter plot, drop-down) is considered a chart. Charts are influenced by and also influence `filterHandler`.

	zChartManager = zigvu.chartManager
		.dataManager(dataManager)
		.filterHander(filterHandler);

* `chartManager`: Charting infrastructure super class
* `dataManager(dataManager)`: The data manager
* `filterHandler(filterHandler)`: The filtering system

#### Line chart with range accessor

This chart plots the values (as defined by `yAxisValue`) in a linear chart for one or more classes across videos. Similar to `cellroti`, there is a range accessor which can be used to "zoom-in" on particular segment of video. This "zoom-in" updates the range chart.

	zLineChart = zigvu.chartManager.line
		.width(width)
		.height(height)
		.selector(selectorId)
		.yaxis(yAxisValue);

* `width(width)`: Width of the chart
* `height(height)`: Height of the chart
* `selector(selectorId)`: Positioning of the chart in the page
* `yaxis(yAxisValue)`: The y-axis value to plot. One of `score`, `area of bbox`, `num of bbox`, `width of bbox`, `height of bbox` etc.

If there are other filters that limit the accessibility of different segments of this line chart, those are indicated by red background areas in the line chart.

#### Range chart with random access to video

This is essentially a "zoom-in" version of the line chart (described above) and updates itself based on selection on the line chart. Clicking anywhere on this chart updates the video display to point to the video frame indicated by the click.

	zRangeChart = zigvu.chartManager.range
		.width(width)
		.height(height)
		.selector(selectorId)
		.yaxis(yAxisValue);

* `width(width)`: Width of the chart
* `height(height)`: Height of the chart
* `selector(selectorId)`: Positioning of the chart in the page
* `yaxis(yAxisValue)`: The y-axis value to plot - has to be same as associated line chart

#### Class list

This is a scrolling text list for selection of classes during new annotation

	zClassList = zigvu.chartManager.list
		.width(width);

Since this list is for annotation, this class does not respect any filters.

#### Toggle switches

Following toggle switches are available to change behavior of the application:

* `zigvu.chartManager.heatmapSwitch`
* `zigvu.chartManager.annotationSwitch`
* `zigvu.chartManager.historySwitch`
* `zigvu.chartManager.panelSwitch`

#### Analysis Panels

The application is composed of the video display static panels and dynamic panels that can contain one or more of following tools:

* Line and range charts (described above)
* Scatter plot (for investigating class confusions)
* Chia-results selection (e.g., limit scores between 0.5 and 0.8)
* Data management (e.g., clearing local caches, synching new updates to server)

Dynamic panels can be swapped in/out on-demand based on the need of analysis.

