# Analysis 0011: Network Socket Endpoint Map

Status: Draft

Date: 2026-06-25

Linux base:

```text
repo: /media/nia/scsiusb/dev/linux-cap/linux
branch: capsched-linux-l0
commit: 4edcdefd4083ae04b1a5656f4be6cd83ae919ef4
```

## Purpose

This note maps Linux sockets to CapSched EndpointCap design. Sockets are not
just files and not just network namespace objects. They are file-backed handles
to protocol-specific mutable state with many operation-specific security hooks.

## Existing Linux Shape

Evidence:

- `include/linux/net.h` around lines 137-146 defines `struct socket` with
  state, type, flags, `struct file *file`, `struct sock *sk`, protocol ops, and
  wait queue.
- `include/linux/net.h` around lines 181-249 defines `struct proto_ops`,
  including bind, connect, accept, listen, shutdown, setsockopt, getsockopt,
  sendmsg, recvmsg, mmap, splice, and protocol-specific callbacks.
- `include/net/sock.h` around lines 365-585 defines `struct sock`, including
  socket linkage, callbacks, cgroup data, destructor, reuseport, and state
  callbacks.
- `include/net/net_namespace.h` around lines 62-202 defines `struct net`, a
  large mutable network namespace containing routing, protocol, netfilter,
  BPF, device, netlink, xfrm, and per-protocol state.

CapSched reading:

`EndpointCap` for sockets must bind at least:

```text
Domain epoch
socket object identity/generation
network namespace or network service authority
operation type
address/peer/port scope when applicable
send/receive/bind/listen/connect rights
budget or rate policy when service work is involved
```

## Socket Creation and File Binding

Evidence:

- `net/socket.c` around lines 1580-1694 implements `__sock_create()`.
  It calls `security_socket_create()`, allocates a socket, calls the protocol
  family create operation, gets module references, and calls
  `security_socket_post_create()`.
- `sock_create()` around lines 1707-1711 creates sockets in
  `current->nsproxy->net_ns`.
- `sock_create_kern()` around lines 1725-1729 creates kernel sockets in an
  explicitly supplied network namespace.
- `sock_alloc_file()` around lines 525-551 creates a pseudo file, stores the
  socket in `file->private_data`, stores the file in `sock->file`, and installs
  socket file operations.
- `sock_from_file()` around lines 574-585 recovers the socket from a file only
  if `file->f_op == &socket_file_ops`.
- `__sys_socket()` around lines 1788-1807 creates the socket and maps it to an
  fd.

CapSched reading:

There are at least three natural policy moments:

```text
create:
  family/type/protocol/netns authority

bind to file/fd:
  fd endpoint object created

install fd:
  endpoint becomes reachable through task's fdtable
```

Potential endpoint object:

```text
SocketEndpoint =
  file object
  socket object
  sock object
  net namespace/service
  protocol family
  operation rights
  epoch/generation
```

## Operation Hooks

Evidence:

- `security/security.c` around lines 4180-4328 provides LSM hooks for
  socket_create, socket_post_create, socketpair, bind, connect, listen, accept,
  sendmsg, and recvmsg.
- `security/security.c` around lines 4126-4178 explains why Unix domain socket
  hooks are needed for abstract namespace sockets: the actual peer is only known
  inside AF_UNIX code.
- `net/socket.c` around lines 1912-1956 handles bind through
  `security_socket_bind()` and protocol `bind`.
- `net/socket.c` around lines 1960-1988 handles listen through
  `security_socket_listen()` and protocol `listen`.
- `net/socket.c` around lines 1995-2060 handles accept by allocating a new
  socket/file before the protocol accept operation.
- `net/socket.c` around lines 2118-2160 handles connect through
  `security_socket_connect()` and protocol `connect`.
- `net/socket.c` around lines 2217-2269 handles send/sendto.
- `net/socket.c` around lines 2277-2327 handles recv/recvfrom.
- `net/socket.c` around lines 2627-2775 handles sendmsg/sendmmsg.
- `net/socket.c` around lines 2878-2985 handles recvmsg.
- `net/socket.c` around lines 785-790 and 1144-1148 call send/recv LSM hooks
  before protocol operation.

CapSched reading:

Socket endpoint authority is operation-specific. A single broad "socket fd may
be used" capability would be too coarse.

Minimum operations to model separately:

```text
create
bind
listen
accept
connect
send
receive
set option
get option
shutdown
peer inspection
async notification ownership
```

Accept is especially important because it creates a new socket/file from an
existing listening socket. This is a capability derivation event:

```text
ListenEndpointCap + AcceptRight + peer policy
  -> new SocketEndpointCap for accepted connection
```

## Landlock Socket Lessons

Evidence:

- `security/landlock/net.c` around lines 301-375 implements Landlock hooks for
  socket bind, connect, and sendmsg.
- It distinguishes TCP bind, TCP connect, UDP bind, UDP connect/send, and UDP
  autobind.
- `security/landlock/task.c` around lines 301-460 handles abstract Unix socket
  scoping and signal-related ownership through file owner state.

CapSched reading:

Landlock demonstrates two useful design lessons:

1. Socket policy is not uniform across protocols.
2. Some decisions need peer or address information that is not available at
   generic fd lookup time.

Therefore CapSched should not freeze all socket authority at `socket()` alone.
It should freeze a base endpoint and then derive operation-specific frozen uses
as address/peer information becomes available.

## Network Namespace Boundary

Evidence:

- `include/net/net_namespace.h` around lines 62-202 shows that `struct net` is a
  large mutable state bundle containing routing, protocol state, devices,
  netfilter, BPF, xfrm, netlink sockets, and per-protocol namespaces.
- `sock_create()` uses `current->nsproxy->net_ns`.
- `sock_create_kern()` can create sockets for an explicit `struct net`.

CapSched reading:

Network namespace is a useful object-view policy input, but it should not be
the final Domain boundary. A CapSched Domain may use:

```text
netns as compatibility view
network service Domain as control-plane boundary
QueueCap for direct NIC queues
EndpointCap for socket operations
BudgetTicket for network service work
```

## Capability Mapping

| Linux operation | CapSched concept | Notes |
| --- | --- | --- |
| `socket()` | create base SocketEndpoint | family/type/protocol/netns policy |
| `bind()` | bind right | address/port scope matters |
| `listen()` | listen right | backlog and service policy matter |
| `accept()` | derive endpoint | creates new file/socket endpoint |
| `connect()` | connect right | peer/address scope matters |
| `sendmsg()` | send right plus budget/rate | UDP may include destination per send |
| `recvmsg()` | receive right | may expose peer metadata |
| `setsockopt()` | socket control right | can mutate protocol behavior |
| kernel socket | service Domain authority | should not inherit caller authority ambiently |
| abstract Unix socket | scoped IPC endpoint | peer only known in AF_UNIX layer |

## Formal Implication

The first EndpointCap model should not treat sockets as ordinary file reads and
writes. It should contain:

```text
SocketEndpoint(endpoint_id, file_gen, sock_gen, net_view, proto, epoch)
SocketOp in {bind, listen, accept, connect, send, recv, setopt, shutdown}
PeerScope or AddrScope
DerivedEndpoint for accept/connect/socketpair
```

## Preliminary Conclusion

Sockets are a prime example of why CapSched must keep the scheduler narrow.
RunCap can decide that a task may execute. It cannot decide all socket
semantics. Socket authority belongs at typed endpoints, with LSM/Landlock as
policy front-ends and service Domains or queue leases for deeper network
isolation.
