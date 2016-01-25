### Populate Cellroti

#### Notes

* `det_group` is the database equivalent of `brand_group` in the UI


#### 1. Setup meta data

##### 1.1 

Task: Create in Cellroti {organization, detectable, client_detectable, det_group, sport, event_type, league, team, season}

Role: Zigvu Admin

Frequency: Once

Result: Database entries created

##### 1.2

Task: Create in Cellroti {game, game_team, event, video}

Role: Zigvu User

Frequency: For each game

#### 2. Import data from Khajuri

##### 2.1

Task: Use executables in `khajuri/Logo/PipelineCommunication` to:

* Get list of detectable from Cellroti
* Match chia label_mapping.txt with the list of detectable
* Extract localizations from JSON, frames from video
* Send extracted data to Cellroti, confirm receipt OK/error
* In Cellroti, this will automatically kick off delayed job

Role: Zigvu Admin/User

Results:

* Localization data and associated frames saved to `/sftp/sftpuser/uploads/videoId` folder
* Delayed job for ingesting video kicked off

Frequency: For each game. (Note: First two tasks need to be done only once if using the same chia model)

##### 2.2

Task: Monitor the kicked off delayed_job. If error, re-run.

Role: Zigvu Admin

Result: Video in release queue

Frequency: For each game

#### 3. Add/remove det_groups

##### 3.1

Task: Add det_group: Upon client request:

* Add detectables in det_group to the list of detectables the client can access
* If det_group doesn't exist, create det_group [Note: This will automatically kick off delayed job].
* If det_group exists (or upon completion of delayed job), review det_group data/chart
* Add det_group to the list of det_groups the client can access
* If the client request was to "update" det_group with less/more detectable, perform above steps with brand new det_group and perform step 3.2 for the old det_group

Role: Zigvu Admin

Results:

* Delayed job for computing det_group kicked off
* After delayed job is done, det_group in release queue

Frequency: Upon client request

##### 3.2

Task: Remove det_group: Upon client request:

* Remove det_group from the list of det_groups client can access
* Remove all orphaned detectables from the list of detectables client can access
* If no client references this det_group, delete

Role: Zigvu Admin

Result: det_group not accessible to client. If no client referencing it, det_group and associated data deleted

Frequency: Upon client request

___

### Manage Progress of Metrics Creation

All metrics creation (video ingest or new det_group creation) happens in `delayed_job` background tasks. There are two queues - one for video ingestion and another for det_group creation - for `delayed_job`. These queues can have different priority in terms of ability to access compute resources.

Currently, if video ingestion task (or job) is on-going and a det_group creation task/job kicks off, the new det_group may or may not be evaluated for the currently ingesting video. This is a known race condition and it is the duty of the admin to ensure that all det_groups are created prior to releasing the video to clients.

All metrics creation happens through `Client.zigvu_client` user - individual users of other clients are NOT allowed to start metrics creation. In fact, client users cannot access any metrics until "released" by an admin.

The UI for managing progress of metrics creation can be found in the `admin` interface of cellroti. It consists of the following parts:

#### Working Jobs

All tasks/jobs that are currently in the `working` state in delayed_job are listed here. Once jobs are here, until they fail (after 3 retries) or they succeed, they cannot be changed/cancelled. 

This section also provides a way to access `delayed_job`'s native web interface for job management.

#### Release to Client

All jobs that have successfully finished computing are queued for release in this section. An admin can review the computed metrics before "releasing" it so that the client can access it.

#### Queued Jobs

Jobs that are queued for running in delayed_job are displayed here. If the queue doesn't change for a long time, ensure that `bin/delayed_job start n` where `n = num_of_threads_to_run` has been issued in a machine.

#### Failed Jobs

Jobs that fail due to any exception (e.g., temporary unavailability of database) are retried automatically by `delayed_job` three times before placing them in the fail queue. Once the underlying issue of failure has been resolved, the job can be requeued from the UI.

___

### Pipeline Communication notes

#### Status message protocol

* `success` : indicates that all tasks in requested URI call was executed successfully
* `error` : indicates communication error with cellroti - most likely authentication issue. Check to see that the right `authentication_token` is present in `~/.profile` file
* `failure` : indicates that there was no communication error but at least one of the steps in processing the requested URI call could not be executed successfully
