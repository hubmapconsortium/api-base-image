# api-base-image

The docker image used as the base/parent image for the various HuBMAP API and UI applications. The current version is based on the RedHat Universal Base Image 10.0 with Python 3.13.9 installed.

````
docker build -t hubmap/api-base-image:1.2.0 .
````

Then publish it to the DockerHub:

````
docker login
docker push hubmap/api-base-image:1.2.0
````

To use the published image:

````
docker pull hubmap/api-base-image:1.2.0
````

In the child image Dockerfile:

```
FROM hubmap/api-base-image:1.2.0
```
