# dht - Distributed Hash Table using Dispatch Library

A distributed hash table (DHT) is a class of a decentralized distributed system that provides a lookup service similar to a hash table, in which (key, value) pairs are are stored and retrieved efficiently.

The DHT scales up by partitioning the hashed `key` space between the nodes. Each (key, value) set is stored on two replicas for redundancy.

In case of failures two replicas may diverge. Conflicts are handled on read `get/1` by picking an arbitrary value and updating the diverging replica.

## Installation

The application is standalone. To run execute:

```bash
mix deps.get
iex --name node1@127.0.0.1 -S mix
```

Other nodes will automatically attempt to connect to `node1@127.0.0.1` on launch.

In order to set a value `1` in the DHT for the key `:foo` use the `set/2` function.

```elixir
iex(node1@127.0.0.1)1> Dht.Service.set(:foo, 1)
true
```

To get the values of 2 replicas for the key `:foo` call `get_values/1`.

```elixir
iex(node1@127.0.0.1)2> Dht.Service.get_values(:foo)
[1, 1]
```

If the replicas diverged then the values will not match.
For example if the replica server got restarted then its contents will get lost.

```elixir
iex(node1@127.0.0.1)3> Dht.Service.get_values(:foo)
[1, nil]
```

Use `get/1` to get the values for the key and if the values do not match it will resolve the conflict and update the replicas.

```elixir
iex(node1@127.0.0.1)4> Dht.Service.get(:foo)
1
18:36:43.532 [info]  Updated replica #PID<15428.208.0> with {:foo, 1}
```

The next `get/1` will not show a conflict.

```elixir
iex(node1@127.0.0.1)5> Dht.Service.get(:foo)
1
```