OpenVPN server in a Docker container complete with an EasyRSA PKI CA.

**Upstream Links:**
- Dockerhub [krishnachalise418/openvpn-docker](https://hub.docker.com/r/krishnachalise418/openvpn-docker)
- Github: [chalisekrishna418/openvpn-docker](https://github.com/chalisekrishna418/openvpn-docker)

## Quick Start
- Pick a name for the `$OVPN_DATA` data volume container. Users are encouraged to replace example with a descriptive name of their choosing.

  ```
  OVPN_DATA="ovpn-data-example"
  ```
- Initialize the `$OVPN_DATA` container that will hold the configuration files and certificates. The container will prompt for a passphrase to protect the private key used by the newly generated certificate authority.

  ```
  docker volume create --name $OVPN_DATA
  docker run -v $OVPN_DATA:/etc/openvpn --rm krishnachalise418/openvpn-docker -u udp://VPN.SERVERNAME.COM
  docker run -v $OVPN_DATA:/etc/openvpn --rm -it krishnachalise418/openvpn-docker ovpn_initpki
  ```
- Start OpenVPN server process

  ```
  docker run -v $OVPN_DATA:/etc/openvpn -d -p 1194:1194/udp --cap-add=NET_ADMIN krishnachalise418/openvpn-docker
  ```
- Generate a client certificate without a passphrase

  ```
  docker run -v $OVPN_DATA:/etc/openvpn --rm -it krishnachalise418/openvpn-docker easyrsa build-client-full CLIENTNAME nopass
  ```

- Retrieve the client configuration with embedded certificates

  ```
  docker run -v $OVPN_DATA:/etc/openvpn --rm krishnachalise418/openvpn-docker ovpn_getclient CLIENTNAME > CLIENTNAME.ovpn
  ```

### Next Steps

### Docker Compose

## TLDR;
```
version: '3'
services:
  openvpn:
    cap_add:
     - NET_ADMIN
    image: krishnachalise418/openvpn-docker
    container_name: openvpn
    ports:
     - "1194:1194/udp"
    restart: always
    volumes:
     - ./openvpn-data/conf:/etc/openvpn
EOF
```

- Create all necessary directories
```
mkdir -p /opt/openvpn/
cd /opt/openvpn/
mkdir -p /opt/openvpn/openvpn-data
```

- Create Docker Compose
```
cat <<EOF >>docker-compose.yaml
version: '2'
services:
  openvpn:
    cap_add:
     - NET_ADMIN
    image: krishnachalise418/openvpn-docker
    container_name: openvpn
    ports:
     - "1194:1194/udp"
    restart: always
    volumes:
     - ./openvpn-data/conf:/etc/openvpn
EOF
```

- Initialize the `$OVPN_DATA` container that will hold the configuration files and certificates with nopass
```
docker-compose run --rm openvpn ovpn_genconfig -u udp://vpn089.prd.grepsr.net
docker-compose run --rm openvpn ovpn_initpki nopass
```

- Start containers with docker-compose
```
docker-compose up -d openvpn
```

- Watch Logs
```
docker-compose logs -f openvpn
```

**Creating and Revoking Client Certificates**

- Creating:
  ```
  cd /opt/openvpn
  export CLIENTNAME="CLIENT.NAME"
  docker-compose run --rm openvpn easyrsa build-client-full $CLIENTNAME nopass
  docker-compose run --rm openvpn ovpn_getclient $CLIENTNAME > VPN-users/$CLIENTNAME.ovpn
  cat VPN-users/$CLIENTNAME.ovpn
  ```

- Revoking:
  ```
  cd /opt/openvpn
  export CLIENTNAME="CLIENT.NAME"
  docker-compose run --rm openvpn ovpn_revokeclient $CLIENTNAME remove
  ```

## Benefits of Running Inside a Docker Container

**The Entire Daemon and Dependencies are in the Docker Image**
This means that it will function correctly (after Docker itself is setup) on all distributions Linux distributions such as: Ubuntu, Arch, Debian, Fedora, etc. Furthermore, an old stable server can run a bleeding edge OpenVPN server without having to install/muck with library dependencies (i.e. run latest OpenVPN with latest OpenSSL on Ubuntu 12.04 LTS).

**It Doesn't Stomp All Over the Server's Filesystem**
Everything for the Docker container is contained in two images: the ephemeral run time image (`krishnachalise418/openvpn-docker`) and the `$OVPN_DATA` data volume. To remove it, remove the corresponding containers, `$OVPN_DATA` data volume and Docker image and it's completely removed. This also makes it easier to run multiple servers since each lives in the bubble of the container (of course multiple IPs or separate ports are needed to communicate with the world).

**Some (arguable) Security Benefits**
At the simplest level compromising the container may prevent additional compromise of the server. There are many arguments surrounding this, but the take away is that it certainly makes it more difficult to break out of the container. People are actively working on Linux containers to make this more of a guarantee in the future.

### Differences from `kylemanna/openvpn`

- Continual Weekly updates with updated OpenVPN versions

## Please use this for production at your own after you go through all the checks.
