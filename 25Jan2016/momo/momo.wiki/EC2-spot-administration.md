#### Web interface

The admin interface to set up spot configuration can be found at:

`http://localhost:3000/users/admin/spot`

There are two separate configurations - one for model training and another for video evaluation. Following parameters can be set for each configuration:

* Instance type: All available instances for spot prices (updated 11/25/2013) using the same keyword as used in EC2 spot pricing drop down menu
* Instance price: Dollar amount bid price
* Max number of instances: The maximum number of instances to concurrently run for this configuration
* Idle Time Before Termination: Number of minutes after all queue tasks have been completed to keep this instance alive
* Instance Start Failure Behavior: How to handle case when spot request fails (e.g., when bid price is low). Current options include {"terminate", "rebid", "ondemand"}. Terminate option essentially stops handling spot request failure. Rebidding allows to rebid using the same instance price. On-demand instructs backend to use on-demand instance in case spot is not available.

The configuration is saved and unless changed by an admin, the last set configuration is shown on both the UI and builder interface. Additionally, when the database is seeded, following configuration option are default selected for both the model trainer and video evaluator:

* Instance type: "c3.large"
* Instance price: 0.05
* Max number of instances: 1
* Idle Time Before Termination: 30
* Instance Start Failure Behavior: "terminate"

#### Builder API interface

Any update made in the UI can be immediately accessed using the builder API interface using following URL:

`GET http://localhost:3000/builder/spot_managers`

Returns:

* Parameters described in UI section above
* id: database id of this configuration change entry by user
* task: one of {model, video} describing whether this configuration is for the model builder or video evaluator

[Note that authentication is required to access this URL and is described in the JSON authentication wiki page]

Example:

> curl -X GET -H "Content-Type: application/json" -d '{"auth_token":"sx8HmVz1gtUT5szudz2w"}' http://localhost:3001/builder/spot_managers

_Returns_

	[{"id":12,"instance_type":"cc2.8xlarge","price":4.0,"task":"model","num_instance":1,
	"idle_time":3,"failure_behavior":"terminate"},{"id":13,"instance_type":"g2.2xlarge",
	"price":4.0,"task":"video","num_instance":54,"idle_time":1342,"failure_behavior":"ondemand"}]
