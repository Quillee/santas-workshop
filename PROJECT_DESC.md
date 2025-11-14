# Santa's Distributed Gift Management System

## Overview

This project is a progressive distributed systems learning experience that builds a complete gift management system for Santa's operations. 
Starting with fundamental concepts and building up to complex distributed algorithms, 
you'll implement three interconnected services that showcase key distributed systems principles.

### Why Distributed Systems?

Cause I wanna learn cool stuff

## Project Components

### Phase 1: Gift ID Generator (Beginner) - Zig

Build a distributed unique ID generation system for tracking gifts globally using **Zig** for maximum performance and control.

**Concept**: Each gift needs a globally unique identifier that can be generated without coordination between Santa's workshops. 
Based on Twitter's Snowflake algorithm, our Gift ID Generator creates sortable, unique IDs.

**ID Structure** (64 bits):
```
0 | 41 bits timestamp | 10 bits workshop ID | 12 bits sequence | 1 bit gift type
```

**Key Features**:
- Time-ordered IDs (gifts can be sorted by creation time)
- No network calls required for ID generation
- Embedded workshop location data
- Special bit for gift type (0 = toy, 1 = coal)
- Handles up to 1024 workshops worldwide
- 4096 IDs per millisecond per workshop

**Implementation Requirements**:
- Handle clock skew and backwards time jumps
- Implement sequence number rollover
- Provide ID parsing to extract metadata
- Build REST API for ID generation service

**Why Zig for this service**:
- Predictable performance with no GC pauses
- Direct bit manipulation capabilities
- Comptime computations for bit masks
- Tiny binary size (~500KB)
- Learn manual memory management in a controlled environment

**Learning Objectives**:
- Understand distributed ID generation patterns
- Master Zig's bit manipulation and comptime features
- Handle time synchronization issues
- Build high-performance HTTP servers with `httpz` or `zap`
- Explore Zig's error handling with error unions

---

### Phase 2: Elf Workshop Task Queue (Intermediate) - Go

Expand the system with a distributed task queue for managing gift production using **Go**'s excellent concurrency primitives.

**Concept**: With unique Gift IDs in place, build a fault-tolerant task queue that distributes gift manufacturing tasks across multiple workshop nodes. Tasks are tagged with Gift IDs for tracking.

**Architecture**:
```
Producer (Letter Processor) -> Queue Partitions -> Consumer Pools (Elf Workers)
                                     |
                                     v
                            Progress Tracker (uses Gift IDs)
```

**Key Features**:
- **Task Types**: Assembly, Painting, Quality Check, Packaging
- **Priority Levels**: Express (Dec 24), Standard, Nice-child bonus
- **Fault Tolerance**: Task acknowledgment and retry mechanisms
- **Load Balancing**: Work-stealing algorithm between workshops
- **Dependencies**: Task DAG (Directed Acyclic Graph) support

**Implementation Requirements**:
- At-least-once delivery guarantee
- Idempotent task execution
- Dead letter queue for failed tasks
- Distributed task status tracking
- Workshop health monitoring

**Why Go for this service**:
- Goroutines perfect for worker pools
- Channels for elegant task distribution
- Rich ecosystem (NATS, Redis, Asynq)
- Built-in context for cancellation/timeouts
- Excellent standard library for networking

**Learning Objectives**:
- Master goroutines and channels for concurrency
- Implement worker pools with work-stealing
- Use context for graceful shutdowns
- Integrate with NATS for pub/sub messaging
- Build production-ready services with Echo/Gin
- Implement distributed tracing with OpenTelemetry

---

### Phase 3: Gift Exchange Matcher (Advanced) - OCaml

Complete the system with a privacy-preserving distributed matching service using **OCaml**'s strong type system and functional programming paradigms.

**Concept**: Using the Gift IDs and task queue infrastructure, implement a distributed Secret Santa matching algorithm that works across multiple regions while preserving privacy and handling constraints.

**Challenge Requirements**:
- No participant can match with themselves
- Respect exclusion lists (family members)
- Handle budget constraints
- Ensure atomic assignments (all or nothing)
- Maintain assignment secrecy
- Support late participant additions

**Distributed Algorithm**:
1. **Phase 1 - Registration**: Participants register with constraints
2. **Phase 2 - Distributed Graph Building**: Each region builds local constraint graph
3. **Phase 3 - Leader Election**: Elect coordinator using Raft consensus
4. **Phase 4 - Matching**: Distributed perfect matching algorithm
5. **Phase 5 - Two-Phase Commit**: Ensure atomic assignment
6. **Phase 6 - Secure Distribution**: Encrypted result delivery

**Implementation Requirements**:
- Raft consensus for coordinator election
- Homomorphic encryption for privacy
- Two-phase commit protocol
- Rollback mechanism for failures
- Audit log using Gift IDs

**Why OCaml for this service**:
- Type system ensures matching correctness at compile time
- Algebraic data types perfect for modeling constraints
- Pattern matching for elegant state machines
- Immutability simplifies distributed consensus
- Effects system (Eio) for modern concurrency

**Learning Objectives**:
- Model complex domains with algebraic data types
- Implement state machines with pattern matching
- Use Result/Option types for error handling
- Build async systems with Lwt or new Eio
- Integrate with Oraft for consensus
- Create type-safe APIs with Dream framework

## System Integration

The three components work together:

1. **Gift ID Generator** provides unique identifiers for all gifts and exchanges
2. **Task Queue** uses Gift IDs to track manufacturing progress
3. **Exchange Matcher** assigns Gift IDs to recipients and queues gift tasks

## Technical Stack Recommendations

### Multi-Language Architecture

**Phase 1 - Gift ID Generator (Zig)**:
- **Web Framework**: `httpz` or `zap` for HTTP serving
- **Serialization**: Custom or `protobuf-zig`
- **Testing**: Built-in test framework
- **Deployment**: Single static binary (~500KB)

**Phase 2 - Task Queue (Go)**:
- **Web Framework**: Echo or Gin
- **Message Queue**: NATS or Asynq
- **State Storage**: Redis with go-redis/v9
- **Dependency Injection**: Uber fx
- **Testing**: testify + gomock

**Phase 3 - Exchange Matcher (OCaml)**:
- **Web Framework**: Dream
- **Async Runtime**: Lwt or Eio (effects-based)
- **Consensus**: Oraft
- **Serialization**: ppx_deriving_yojson
- **Testing**: Alcotest + QCheck

**Shared Infrastructure**:
- **RPC**: gRPC with protobuf (all languages have support)
- **Service Discovery**: Consul or etcd
- **Monitoring**: Prometheus + Grafana
- **Tracing**: OpenTelemetry
- **Container Runtime**: Docker + Kubernetes

## Getting Started

### Development Setup

**Prerequisites**:
```bash
# Zig (Gift ID Generator)
curl -sSf https://ziglang.org/download/0.11.0/zig-linux-x86_64-0.11.0.tar.xz | tar xJ
export PATH=$PATH:./zig-linux-x86_64-0.11.0

# Go (Task Queue)
wget https://go.dev/dl/go1.21.5.linux-amd64.tar.gz
sudo tar -C /usr/local -xzf go1.21.5.linux-amd64.tar.gz
export PATH=$PATH:/usr/local/go/bin

# OCaml (Exchange Matcher)
sh <(curl -sL https://raw.githubusercontent.com/ocaml/opam/master/shell/install.sh)
opam init
opam switch create 5.1.0
eval $(opam env)
```

### Progressive Implementation

1. **Phase 1 - Zig**: Start with the Gift ID Generator
   - Implement basic ID generation algorithm
   - Add HTTP server with `std.http.Server`
   - Upgrade to `httpz` for routing
   - Add benchmarks and optimize

2. **Phase 2 - Go**: Build the Task Queue
   - Create worker pool with goroutines
   - Implement in-memory queue with channels
   - Add Redis for persistence
   - Integrate NATS for distribution

3. **Phase 3 - OCaml**: Implement Exchange Matcher
   - Model constraints with algebraic types
   - Build matching algorithm
   - Add Dream web endpoints
   - Implement Raft consensus

4. **Integration**: Connect all services
   - Define protobuf schemas
   - Implement gRPC communication
   - Add end-to-end tests
   - Deploy with Docker Compose

## Glossary

**Atomic Operation**: An operation that completes entirely or not at all, with no intermediate state visible to other processes.

**Byzantine Fault Tolerance**: The ability of a system to function correctly even when some nodes fail in arbitrary ways, including maliciously.

**CAP Theorem**: States that a distributed system can only guarantee two of: Consistency, Availability, and Partition tolerance.

**Circuit Breaker**: A pattern that prevents cascading failures by temporarily stopping requests to a failing service.

**Clock Skew**: The difference in time between different computer clocks in a distributed system.

**Consensus Algorithm**: A protocol for getting distributed nodes to agree on a single value (e.g., Raft, Paxos).

**CRDT (Conflict-free Replicated Data Type)**: Data structures that can be replicated across nodes and merged without conflicts.

**Dead Letter Queue**: A queue for messages that cannot be processed successfully after multiple attempts.

**Eventual Consistency**: A consistency model where all nodes will eventually converge to the same state.

**Gossip Protocol**: A communication protocol where nodes randomly share information with peers to disseminate data.

**Homomorphic Encryption**: Encryption that allows computations on encrypted data without decrypting it.

**Idempotency**: The property where an operation produces the same result regardless of how many times it's performed.

**Leader Election**: The process of choosing a single node to coordinate activities in a distributed system.

**Load Balancing**: Distributing work across multiple nodes to optimize resource utilization.

**Message Queue**: A communication method where messages are placed in a queue for asynchronous processing.

**Partition Tolerance**: The ability of a system to continue operating when network failures prevent some nodes from communicating.

**Pub/Sub (Publish/Subscribe)**: A messaging pattern where publishers send messages to topics and subscribers receive them.

**Quorum**: The minimum number of nodes that must agree for an operation to succeed.

**Raft**: A consensus algorithm designed to be understandable, used for leader election and log replication.

**Service Discovery**: The automatic detection of services and their network locations in a distributed system.

**Two-Phase Commit**: A protocol that ensures all nodes either commit or abort a transaction together.

**Vector Clock**: A data structure used to determine the partial ordering of events in a distributed system.

**Work Stealing**: A load balancing technique where idle nodes take work from busy nodes' queues.
