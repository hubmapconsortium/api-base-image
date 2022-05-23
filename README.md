# api-base-image

The docker image to be used as the base/parent image for the various HuBMAP APIs. The current version is based on the Red Hat Universal Base Image 8.6 and has Python 3.9.7 installed.

````
docker build -t hubmap/api-base-image:1.0.0 .
````

Then publish it to the DockerHub:

````
docker login
docker push hubmap/api-base-image:1.0.0
````
