# api-base-image

The docker image to be used as the base/parent image for the various HuBMAP APIs. The current version is based on the Red Hat Universal Base Image 10.0 and has Python 3.13.9 installed.

````
docker build -t hubmap/api-base-image:1.2.0 .
````

Then publish it to the DockerHub:

````
docker login
docker push hubmap/api-base-image:1.2.0
````
