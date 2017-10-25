# As a wallet provider, I want to know when a send transaction is received for a particular address

### Glossary
* event - send transaction was committed
* filter - a request to notify about particular events
* subscriber - one who will receive events for particular filter
* replay filter - filter that allows to query for events from blocks in the past

### Access points, existing
* HonteD.API - sync, async (with pid or registered server that will receive events)
* JSONRPC2 - sync only
### Access points, proposed ways to handle async
* Websocket - sync and async || <- chosen solution
* GRPC - sync and async. Overkill?

### Websocket implementation plan
start cowboy with ws handler
modify ws handler to keep state and interpret incoming jsons as commands
use wsrpc (modified version of jsonrpc2 that handles events)
handle requests - response pairing with ids
handle events - messages without

### Replay filters
Q. Do we need those now? Are they planned in the future? A. We need those and we should plan it in some other story.

### Filter persistence
We need to limit lifetime of filters (memory!) but stay simple and clean. Two method
are proposed. First, ability of receiving side to receive this (subscriber is gone?
remove filter!). Second, manual removal of the filter. Since we will not have
replay filters yet, dropping filters after some timeout, as Ethereum does, would lead
to loss of information about events. A: go for manual removal of the filter.

### Architecture
Naive filter list processing is O(n*m) for n filters and m transactions. This is too slow and it can't be a part of critical path of a node. A: processing moved away from critical path.
