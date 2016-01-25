## Overview

This wiki is the "living" document of the math that goes to construct the metrics described in Khajuri issue34 and needed by Cellroti to construct analytic chart. It is expected that this document will evolve, but the files in module `cellroti/app/Metrics` is expected to follow this document exactly.

The ultimate goal from all caffe number crunching is to find `Brand Effectiveness` of a particular brand. Note that a client may employ several detectables to represent a brand - e.g., McDonalds might employ "I'm lovin' it" or "go.mcd.com" as detectables. If both appear in the same video frame, the brand effectiveness will increase. This concept is captured by `Brand Groups` in cellroti. A client can request various detectables (even of different organization) in one `Brand Group`. Or, they might choose to use a single detectable in a `Brand Group` - for example to compare effectiveness of one sub-brand vs. another.


## Per-Frame Calculations

From chia, we get bounding box and score for all detectables for each frame. To mitigate the effect of spurious false positives, frame-level calculations of detectable metrics are smoothed out using a sliding window. These detectable metric are grouped/aggregated to derive metrics for a `Brand Group`.


### Brand Effectiveness

`brand_effectiveness = w0 * brand_crowding + w1 * visual_saliency + w2 * timing_effectiveness + w3 * spatial_effectiveness`

where `wX` are customizable weights. Each of the sub-component of `brand_effectiveness` should be in the range [0,1]. `brand_effectiveness` also is in the range [0,1].


#### Brand Crowding

For a detectable:

`brand_crowding(detectable) = decayed_average_across_sliding_window( sum( area_ratio(all_detections_in_this_frame)))`

Where:
 * `area_ratio` = area of detection divided by area of frame

For a brand group:

`brand_crowding(brand_group) = brand_crowding(detectables_in_brand_group) / brand_crowding(detectables_in_all_brand_groups)`


#### Visual Saliency

For a detectable:

`visual_saliency(detectable) = decayed_average_across_sliding_window( max( caffe_score(all_detections_in_this_frame)))`

For a brand_group:

`visual_saliency(brand_group) = max( visual_saliency(detectables_in_brand_group))`


#### Timing Effectiveness

For a detectable:

`timing_effectiveness(detectable) = sum( presence(event_within_max_time_window) * time_decay_weight * event_weight) * presence(X, this frame)`

Where:
 * `event_within_max_time_window` is event, if any, at a frame within max_time_window (e.g. 30 seconds) in both the positive and negative time directions (so, a total of 60 seconds)
 * `time_decay_weight` is the scale factor to reduce for events that are far away in time from `this_frame`
 * `event_weight` is the weight of the event (e.g., goal is 1 whereas player change is 0)
 * `presence(X)` is `1` if `visual_saliency(X)` is non-zero, else it is zero

For a brand_group:

`timing_effectiveness(brand_group) = max( timing_effectiveness(detectables_in_brand_group))`


#### Spatial Effectiveness

Screen is divided into 9 quadrants: there are 4 in corner, 1 in middle and 4 along edges but not in corner. If the width/height are not integer divisible by 3, then some padding will be left on right-end and bottom-end of the original frame when marking quadrant boundaries.

For scoring of effectiveness, if the logo covers the center quadrant completely, `spatial_effectiveness(detectable)` is 1. Else, it is dependent on the total size and position of detectable in screen. 

For a detectable:

`interseaction_quadrants(detectable) = quadrant_position_weight * detectable_fraction_in_quadrant(all_detections_in_this_frame)`

where
 * `detectable_fraction_in_quadrant = area_of(fraction_of_detection) / area_of(quadrant)`
 * `quadrant_position_weight` indicates the importance of this quadrant vs. other quadrants

Intersection quadrants is rolled up to measure effectiveness:

`spatial_effectiveness(detectable) = sum_all_quadrants( interseaction_quadrants( detectable))`

Note: The 9 quadrant are hard-coded but their boundaries are dictated by size of frame

For a brand group:

`spatial_effectiveness(brand_group) = max( spatial_effectiveness( detectables_in_brand_group))`


#### View Duration

View duration indicates the total amount of time a detectable is seen in screen.

`view_duration(detectable) = if visual_salience > 0 then time_this_frame_appears else 0`

where:

* `time_this_frame_appears` is the total time a frame appears in screen - this is tied to detection frame rate of video

For a brand group:

`view_duration(brand_group) = max( view_duration( detectables_in_brand_group))`


#### View Persistence

View persistence indicates the amount of time a detectable is seen in screen after it initially appears.

`view_persistence(detectable) = if visual_salience > 0 then 1 else 0`

For a brand group:

`view_persistence(brand_group) = 0 if view_persistence( detectables_in_brand_group) is 0 for this and previous frame`
`view_persistence(brand_group) = (N * time_this_frame_appears) if view_persistence( detectables_in_brand_group) is 0 for this frame but not N previous frames`

where:

* `time_this_frame_appears` is the total time a frame appears in screen - this is tied to detection frame rate of video


### Sliding window and decayed average

The two primary purposes of sliding window are:

* To smooth out scores and potentially minimize the effect of false positives
* Carry influence of events to frames adjoining the event frame (e.g., goal impacts timing effectiveness of not only current frame but also adjacent frames.)

Sliding window is implemented as an array of decayed values. We add scores for each {detectable, frame} to the end of the sliding window and use decay weights to average that score across time. Since each frame value is used in the sliding window, there are three parameters needed to construct a sliding window:

* Sliding window size in seconds - how long we want an event to have influence in time axis (supplied in config file)
* Decay weights - how quickly should an event's influence decay over time (supplied in config file)
* Detection frame rate of video - how many frames does sliding window size correspond to (supplied internally from video metadata)

Decay weights are supplied in config file as an array with highest value of `1` and lowest value of `0`. Internally, the decay weights array is "expanded" to be the size of `detection_frame_rate * sliding_window_size` by extrapolating values in the decay array by index.

Example:

* Detection frame rate = 5 fps
* Sliding window size in seconds = 5 seconds
* Decay weights array = [0.2, 1.0, 0.2]
* Internal weights for each frame = [0.2, 0.27, 0.33, 0.4, 0.47, 0.53, 0.6, 0.67, 0.73, 0.8, 0.87, 0.93, 1.0, 0.93, 0.87, 0.8, 0.73, 0.67, 0.6, 0.53, 0.47, 0.4, 0.33, 0.27, 0.2]



### Frame extraction

Frames are extracted from video to show in cellroti based on detectable raw `prob` scores. To limit the number of frames extracted following rules are set:

* No more than 1 frame is extracted from 1 second worth of video. The frame that gets extracted is the frame that has the highest non-background score within the 1 second window
* At least 1 frame is extracted from 10 second worth of video. If there are no frames with non-zero non-background score, then the last frame in the 10 second window is extracted

Note that frame extraction happens during video data import, prior to brand group creation. Hence, the frames extracted may not fully represent the final `brand effectiveness` score.

