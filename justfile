test:
    mix test

start:
    iex -S mix

start-node-a:
    iex --name node_a@127.0.0.1 -S mix

start-node-b:
    iex --name node_b@127.0.0.1 --eval "Node.connect(:'node_a@127.0.0.1')" -S mix

publish:
    mix hex.publish
