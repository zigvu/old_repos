### Data ingestion from Khajuri

For each `game`, there is assumed to be one `video` which is evaluated against certain number of `detectables`. First we ascertain which `det_group`s present in the database can be constructed from these `detectables`. For each of these `det_group`, relevant metrics are derived for each `frame` and these frame-level metrics are "rolled-up" to create summary metrics.

Hence, other than raw data from Khajuri, all data stored in MongoDB is of the form `{video, det_group}`. Read access for a `{video, det_group}` combination is hence very fast.

Once a client is authenticated and requests a {season, client} or {video, client} data, we parse the Hash in the MongoDB document and create compressed JSONs for use in front end charts. We save a copy of the JSON in memcached for later retrieval.

### Caching - Version 1 - Implemented

For the first version of caching, we divide the data into two parts:

* Meta-data: This is data about season/game/game-events that are entered by analyst.
* Metrics-data: This is data computed from the ingestion process described above

All clients who have access to a season will see the same meta-data, hence it is cached at the season level. The cache key includes the `updated_at` timestamp of the SQL table `season`. The timestamp is updated if any of {season, game, video, event, game_team} class is updated - this invalidates the cache automatically. If no changes to the set classes occurs, the cached json metadata is sent back to caller without database access. [Note that if any of {team, event_type, league, sport} is changed, the season metadata is NOT updated. It is assumed that through some other process, this change is propagated to the metrics-data which will trigger updated action on `video`, which in turn invalidates the cache. For example, if a new team is added at the league level, this SHOULD impact the metrics-data since this team will potentially have some game event which in turn impacts brand-effectiveness. This logic is fairly complicated - hence this needs to be done manually.]

For the metrics data, caching happens at {season, client} level or {game, client}. Each client has certain `det_group`s (brand groups) for which they can access metrics data. Since these `det_group`s are different for different clients, metrics data is NOT shared across clients. The cache key for season data includes the `updated_at` timestamp of SQL tables for both `season` and `client`. The cache is expired if any of the `season` set as described in the last paragraph gets updated. Additionally, the cache is expired if any of {client, client_detectable, det_group} class is updated. Hence, if a client is given access to a new `detectable` (logo) or if a client forms a new `det_group` (brand group), then the cache is automatically invalidated. [Note that if `detectable`s or `det_group`s a client can access changes, it is assumed that through some other process the underlying metrics is computed/updated.]

Currently, all `det_group`s for a client is bundled into a single JSON when client requests for {season, client} or {video, client} data. However, depending on how large this is (few MB should be fine), we might have to limit at most 10 `det_group`s to send to client. In that case, we will have to implement version 2 below.

### Caching - Version 2 - Not Implemented

Ideally, we want to move towards 'Russian Doll Caching' mechanism in which we cache in a multi-layered approach. A possible 'Russian Doll Caching' in our case could be that we cache individual {video, det_group, time_resolution} JSON and enclose these caches in other larger caches customized to individual {season, client} or {game, client}. When a new `video` or `det_group` is introduced, we invalidate the enclosing cache and the particular {video, det_group, time_resolution} cache. Unlike the case in Version `, to rebuild the cache for {season, client}, we need only re-package existing caches - much faster approach.

The main issue with implementing Version 2 is development effort. Given that we don't know how slow MongoDB will be in serving data to the JSONifiers packing data, we might have to implement this eventually.
