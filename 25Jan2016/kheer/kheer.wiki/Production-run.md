#### Convention over configuration

* For now, we run daemons as screens: to help get to the correct screen quicker, specify production or development environments in screen title:

> screen -t "kheer.server.production" -S "kheer.server.production"

* All configs needed to run `kheer` and `khajuri` in VMs is present in `~/.configs/khajuri/*.yaml`. Again, specify production/development environments.

* GPU1/GPU2 machines have following folder structure:
- `/mnt/data/video_analysis` holds `videos`, `models` and `configs`
- Prior to running video analysis in a machine ensure that video is present in `videos/wc14/reformatted/**` in the machine where analysis will run
- `models` and `configs` folders have `production` and `development` subfolders that correspond to production or dev environment respectively.
- Models are tracked by `chiaVersion` in kheer: in production/development of `models` folder, each subfolder is named with `chiaVersionId` from kheer. Inside that folder, there is caffe model, prototxt file and saved boundaries. If any of these have not changed across `chiaVersion`s, soft-link is encouraged
- Within production/development of `configs` folder, there are subfolders, again, that correspond to `chiaVersionId` from kheer. Within those, we can have any number of folders with one or more `config.yaml` files for the actual video processing

#### Start daemons

If daemons haven't been started, start each daemon. (Note: Instructions for production - change in development environment.)

##### Rails server

    screen -t "kheer.server.production" -S "kheer.server.production"
    cd /var/www/kheer
    RAILS_ENV=production rake assets:precompile
    RAILS_ENV=production puma -C config/puma.rb

##### Rails background job

    screen -t "kheer.delayed_job.production" -S "kheer.delayed_job.production"
    cd /var/www/kheer
    RAILS_ENV=production ./bin/delayed_job stop 2
    RAILS_ENV=production ./bin/delayed_job start 2
    RAILS_ENV=production ./bin/ingest_data stop
    RAILS_ENV=production ./bin/ingest_data start

##### Heatmap

    screen -t "khajuri.heatmap.production" -S "khajuri.heatmap.production"
    cd ~/khajuri
    ./messaging/daemons/rpc_server_heatmap_d.py ~/.config/khajuri/heatmap.production.config.yaml 

##### Video process data

    screen -t "khajuri.save_data.production" -S "khajuri.save_data.production"
    cd ~/khajuri
    ./messaging/daemons/rpc_server_video_data_d.py ~/.config/khajuri/video_data.production.config.yaml 

#### Process data into kheer

* Create `ChiaVersion` using kheer UI (if not already present)
* Create `Video` using kheer UI (if not already present)

* Use khajuri exec to populate clips for that video (if not already present). Note: currently the clips must reside in the same machine as kheer

> cd ~/khajuri

> ./hdf5Storage/execs/save_video_quanta_to_hdfs.py ~/.config/khajuri/clip_saver.production.config.yaml <videoFolder> <videoId>

* Create `KheerJob` using kheer UI
* In GPU1/2 where video processing will occur, create a new `config.yaml` file for the new KheerJob. The file name convention of the config file is `game_mp4_filename.config.yaml`. It is easier to copy an existing `config.yaml` file and modify the following:
	- execution -> environment/machine
	- jobs -> process_video -> <all_values> [Note: zigvu_job_id is always 1 for process_video]
	- caffe_input -> <filenames>
	- post_processing -> z_dist_thresholds

* Be sure to copy over `config_scale_decay_factors.json` file to the same folder as config
* When running multiple videos, it is recommended to bunch together a few configs in a folder and run `~/khajuri/process_multiple_videos.py`

#### Export data from kheer

    cd /var/www/kheer
    RAILS_ENV=production rake -T

And follow instructions for export annotation for chia task.
