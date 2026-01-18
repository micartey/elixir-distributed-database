# Eddb

<div align="center">
  <img src="https://img.shields.io/badge/Written%20in-elixir-%238238ab?style=for-the-badge" />
  <img src="https://img.shields.io/badge/Hex.pm-eddb-%235764c9?style=for-the-badge" />
</div>

<br />

`eddb` is a distributed database for unstructured data

## Getting Started

The database can be used in two ways.
You either add it as a dependency or you run it bare bones for a simple distributed key-value store.

```bash
MIX_ENV=prod mix release --overwrite
```

First you need to build the database (this is a very quick process, but you need `mix` installed).
Then you can start the database, but make sure to set a `JWT` secret beforehand!

```bash
export RELEASE_NODE=node1@vpn-ip-address  # Identifier for the node to connect to - this value shall be unique 
export RELEASE_COOKIE="your-cookie-value" # Set a shared cookie so that all nodes can connect together
export JWT_SECRET=ahjsdjajdjkahkjdhasd    # Set a shared JWT secret so that all nodes can decypther the token
_build/prod/rel/eddb/bin/eddb start
```

The instance will be running, but you cannot interact with it directly from the terminal.
For that you will need to open a _remote_ session next to it:

```bash
_build/prod/rel/eddb/bin/eddb remote
```

This is the terminal session you can use to interact with the database.

### Create User

There is no default user initialized.
That means you need to create one yourself:

```ex
iex(eddb@localhost)1> user_create "root", "MyVerySecretPassword", :ADMIN
```

There are 3 different permission levels:

| Permission | Description                                   |
| ---------- | --------------------------------------------- |
| `:ADMIN`   | Have read and write access to all topics      |
| `:READ`    | Have read access to selected topics           |
| `:WRITE`   | Have read and write access to selected topics |

As you can see, there is access control for _selected topics_.
You can add access to a topic for a user using the following command:

```ex
iex(eddb@localhost)1> add_topic_to_user "USERNAME", "TOPIC"
```

## Connect to other nodes

> [!WARNING]  
> 
> This is a WIP, meaning it works perfectly fine, but it is currently fairly complicated to build the mesh of nodes.
> This guide will be improved in the future with qol improvements.

This is a distributed database and as such it is also necessary to connect mutliple nodes together.

```bash
iex(eddb@localhost)1> Node.connect :"node1@vps1"
```

## REST-Endpoints

Here is a collection of `REST` endpoints to use the database.
I urge you to try them out to get familiar with the data, what is returned and how.

### Auth

The `auth` endpoint will return a `JWT` secret which you need to use for all other endpoints to authenticate.
As the secret for that token shall be the same on all nodes, it shouldn't matter on which node you call the endpoints.

```bash
export TOKEN=$(curl -X POST "http://localhost:5342/auth" -d '{"username": "root", "password": "MyVerySecretPassword"}' | jq -r .token)
```

_(The token will be valid for 2 hours)_

### Put

```bash
curl -X PUT "http://localhost:5342/put" \
  -H "Authorization: Bearer $TOKEN" \
  -d '{
    "topic": "test_topic", 
    "key": "asdasd", 
    "value": "value"
  }'
```

### Get

```bash
curl "http://localhost:5342/get?topic=test_topic&key=asdasd" -H "Authorization: Bearer $TOKEN"
```

### Delete

> [!CAUTION]
> 
> There are currently no delete capabilities using REST.
>
> Please delete a topic manually from the console using `delete_topic`.
> Make sure that **all nodes are connected** or else the topic will be replaced and **not** deleted!
