# portainer
docker container stop portainer && \\
docker container rm portainer && \\
docker volume rm portainer_data
$ docker image ls
$ docker image rm 728247220223

docker run -d -p 8000:8000 -p 9443:9443 --name portainer \\
    --restart=always \\
    -v /var/run/docker.sock:/var/run/docker.sock \\
    -v portainer_data:/data \\
    portainer/portainer-ce:latest
