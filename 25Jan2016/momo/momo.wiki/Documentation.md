#### ERD diagram

![Momo](../blob/master/erd.jpg?raw=true)

Note: To create new version of the diagram, create branch and run following command:

> rake erd filetype=dot ; dot -Tjpg erd.dot > erd.jpg ; rm erd.dot

It is recommended that this be run whenever model definition changes and the new ERD diagram be committed with the model definition change commit.

#### Method-level documentation

To see method level documentation, follow steps:

1. First, run `yard doc` to generate documentation. Need to do this only to update documentation after changes made. Do not do this in EC2 instance. In EC2, follow steps below only.
2. Run, server `yard server`
3. Browse on port `8808`