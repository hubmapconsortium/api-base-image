# api-base-image

The `entity-api`, `uuid-api`, `ingest-api`, `search-api`, and `hubmap-auth` docker images are based on the `hubmap/api-base-image:latest` image. To update the base image:

````
docker build -t hubmap/api-base-image:latest .
````

Then publish it to the DockerHub:

````
docker login
docker push hubmap/api-base-image:latest
````
