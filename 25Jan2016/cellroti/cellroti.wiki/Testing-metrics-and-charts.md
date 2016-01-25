### A. Visual Saliency

#### A.a. Raw scores are accurate

1. Create config file with all weights except `be_visual_saliency` to be `0`. `be_visual_saliency` needs to be set to `1`. For array weights, all but the last weight is `0` and the last weight is a `1`.
2. Create three `det_groups`: two with one `detectable` each and the last one with both.
3. Set `@resolutions[t][:num_of_frames] = (t).to_i` in function `getFrameCounters` in file `States::SummaryResolutions`. This effectively prevents averaging of scores
4. Create dummy data with sine wave values between 0 and 1 for the two `detectable`s in step 2:

		vdw = SeedHelpers::VideoDataWriter.new(caffeDataReferenceFile, nil); vdw.generateAndSave(1, 5 * 60 * 1000, :sine)

5. In the multi-line chart, for the first two `det_groups`, we should see raw data and for the last `det_group`, we should see the `max` of the two `det_groups`.
6. In the multi-line chart, inspect that the data points are correct and that none are missing:

		chartManager.ndxManager.setCounterBounds(105,125)
		chartManager.ndxManager.getBEData()

7. Select counter to be half of the sine wave and verify that the visual saliency part of the multi-bar graph is correct. The third `det_group` visual saliency score should be the `max` of the other two `det_group` visual saliency scores.
		
#### A.b. Decayed average in sliding window

1. In graph, find the counter bounds which has two cycles of a `det_group` in the sine data setup described in section `A.a`:

		chartManager.ndxManager.setCounterBounds(105,143)
		chartManager.ndxManager.getBEData()

2. Set config value of `sliding_window_decay_weights` to be a uniform array of `0.2`. This should cause the graph values to change around inflexion points but not in the middle. Verify arithmetically that the resulting values are correct.


### B. Timing effectiveness

#### B.a. Raw scores are accurate

1. Create config file with all weights except `be_timing_effectiveness` to be `0`. `be_timing_effectiveness` needs to be set to `1`. For array weights, all but the last weight is `0` and the last weight is a `1`.

2. Choose/create event with `weight` of `1.0`:

		EventType.all.pluck(:name, :weight)
		eventDistance = Metrics::MetricsEventDistance.new(Video.first.game.events, configReader.dm_es_maxTimeSeconds, configReader.dm_es_timeDecayWeights)
		eventDistance.eventWeights
		
3. In multi-line chart, we should see a sharp peak around event with score of 100%.


#### B.b. Time decay of events

1. Set `event_score_time_decay_weights` to increasing values (e.g., `[0, 0.05, 0.15, 0.2, 0.6]`). In the multi-line charts, we should see step scores symmetric around event times.


### C. Spatial Effectiveness

#### C.a. Raw scores are accurate

1. Create config file with all weights except `be_spatial_effectiveness` to be `0`. `be_spatial_effectiveness` needs to be set to `1`. For array weights, all but the last weight is `0` and the last weight is a `1`.

2. Set all quadrant weights to be `1`. In the multi-line chart, we should see a constant line for each det_group.[Note: small perturbation in multi-line chart suggests that some of the bbox from detection is over-flowing out of quadrant boundaries]. In the spatial position chart, the scores should be symmetric about the center quadrant.

3. Set each quadrant weight to be `0` in turn and update charts. The charts should reflect the new scores.


### D. Brand Crowding

#### D.a. Raw scores are accurate

1. Create config file with all weights except `be_det_group_crowding` and `spatial_crowding_weight` to be `0`. `be_det_group_crowding` and `spatial_crowding_weight` needs to be set to `1`. For array weights, all but the last weight is `0` and the last weight is a `1`.

2. For each det_group, the multi-line chart should have straight lines. Choose a single frame data to ensure that the averages computed are correct:

		Video.first.video_detections.first.frame_detections.where(frame_time: 4640).first.single_detectable_metrics.all.pluck(:detectable_id, :cumulative_area)

#### D.b. Decayed average in sliding window

1. Set `sliding_window_size_seconds_temporal_crowding` to `1` and `sliding_window_decay_weights_temporal_crowding` to a uniform value of `0.2`. This should cause multi-line chart to have a uniformly increasing scores for each det_group. Zoom to initial few values and verify arithmetically that the sliding window values are correct.

### E. Brand Count

1. Create dummy data with broken sine wave values between 0 and 1 for the two `detectable`s in step A.a.2:

		vdw = SeedHelpers::VideoDataWriter.new(caffeDataReferenceFile, nil); vdw.generateAndSave(1, 5 * 60 * 1000, :brokenSine)

2. Set `sliding_window_size_seconds_detection_count` to `1`. This should effectively average detection count values every second.

3. In graph, find the counter bounds which has two cycles of a `det_group` in the sine data setup described above:

		chartManager.ndxManager.setCounterBounds(5,9)

4. Step 3 will return some brand counts which need to be half (or zero) if the averaging is done every two seconds by setting `sliding_window_size_seconds_detection_count` to `2`. Incrementally increasing the counter bounds by a second should update brand count.





 
