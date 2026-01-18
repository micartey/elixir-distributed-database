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
export JWT_SECRET=ahjsdjajdjkahkjdhasd # Need to set a JWT_SECRET (shared with all nodes)
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

## Web Endpoints

### Auth

The `auth` endpoint will return a `JWT` secret which you need to use for all other endpoints to authenticate.
As the secret for that token shall be the same on all nodes, it shouldn't matter on which node you call the endpoints.

```bash
export TOKEN=$(curl -X POST "http://localhost:5342/auth" -d '{"username": "root", "password": "MyVerySecretPassword"}' | jq -r .token)
```

_(The token will be valid for 2 hours)_

### Put

```bash
curl -X PUT "http://localhost:5342/put" -H "Authorization: Bearer $TOKEN" -d '{"topic": "test_topic", "key": "asdasd", "value": "value"}'
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

## Functions

### get

`get` will retrive the data from all neighbors and check which update is the newest.
Only the newest data will be returned.

> [!NOTE]
> This has no affect on the data on the current node.
> If you want the data to be merged, call the `sync` function

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:get, "topic", "key"})
```

### get_local

`get_local` will only retrive the newest data from the current node.
Thus, this operation is significantly faster.

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:get_local, "topic", "key"})
```

### put

`put` will store the data on the current node.
Data with the same key in the same topic will be overwritten, but the old data will be kept in the history.

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:put, "topic", "key", "value"})
```

### put (With optimistic locking)

`put` with optimistic locking is similar to the normal put operation.
However, you can specify the expected current state and **only** if the expection matches with the data on the node, the new data will be stored.

> [!NOTE]
> Contrary to the normal put operation will this operation check the expected data on all nodes and compare it with the newest data

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:put, "topic", "key", "currentValue", "newValue"})
```

### sync

`sync` will merge the data from all neighbors.
The data with the newest timestamp is considered the current state.

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:sync, "topic"})
```

### delete

`delete` will delete data **locally**.

A better solution would be setting the value to nil or any other placeholder value as the newer timestamp would make it the source-of-truth.

```elixir
Database.Database.get_worker("worker1")
|> GenServer.call({:delete, "topic", "key"})

# Or use something like this to delete the data "globally":

Node.list()
|> Enum.map(fn node ->
  Database.Database.get_remote_worker(node, "worker1")
  |> GenServer.call({:delete, "topic", "key"})
end
```
