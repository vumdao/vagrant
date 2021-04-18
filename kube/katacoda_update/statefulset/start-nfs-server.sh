docker run -d --net=host \
    --privileged --name nfs-server \
    katacoda/contained-nfs-server:centos7 \
    /exports/data-0001 /exports/data-0002

# write file
#docker exec -it nfs-server bash -c "echo 'Hello NFS World' > /exports/data-0001/index.html"
