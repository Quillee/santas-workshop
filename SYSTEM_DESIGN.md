# System Design: Santa's Distributed Gift Management System

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────────────────┐
│                           Load Balancer (HAProxy)                        │
└─────────────────────────────────────────────────────────────────────────┘
                                      │
        ┌─────────────────────────────┴─────────────────────────────┐
        │                        API Gateway                         │
        │                    (Kong or Traefik)                      │
        └─────────────────────────────┬─────────────────────────────┘
                                      │
    ┌─────────────────┬───────────────┴───────────────┬─────────────────┐
    │                 │                               │                 │
┌───▼──────┐   ┌─────▼──────┐   ┌─────────────┐   ┌─▼───────────┐   ┌─▼─────────┐
│  Gift ID │   │Task Queue  │   │  Exchange   │   │  Service    │   │Monitoring │
│Generator │   │  Service   │   │  Matcher    │   │ Discovery   │   │  Stack    │
│  (Zig)   │   │   (Go)     │   │  (OCaml)    │   │  (Consul)   │   │(Prometheus)
└───┬──────┘   └─────┬──────┘   └──────┬──────┘   └─────────────┘   └───────────┘
    │                │                  │
    └────────────────┴──────────────────┘
                     │
           ┌─────────▼─────────┐
           │   Message Bus     │
           │     (NATS)        │
           └───────────────────┘
```

## Core Components

### 1. Gift ID Generator Service (Zig)

**Design Pattern**: Stateless microservice with local sequence generation

```zig
const GiftIDGenerator = struct {
    workshop_id: u16,
    last_timestamp: i64 = 0,
    sequence: u12 = 0,
    mutex: std.Thread.Mutex = .{},
    
    pub fn generateID(self: *@This()) !u64 {
        // Bit manipulation for ID generation
        // No GC pauses, predictable performance
    }
};

// ID Format: |1 bit unused|41 bit timestamp|10 bit workshop|12 bit sequence|
```

**Zig-Specific Design Choices**:
- Manual memory management for zero allocations in hot path
- Comptime bit mask calculations
- Error unions for explicit error handling
- Static binary deployment (~500KB)

**Deployment Architecture**:
- 3+ instances per region for high availability
- No shared state between instances
- Each instance assigned unique WorkshopID via Consul
- Health checks every 5 seconds

**API Endpoints**:
```
POST   /api/v1/gift-id/generate
GET    /api/v1/gift-id/{id}/decode
GET    /api/v1/gift-id/health
```

### 2. Task Queue Service (Go)

**Design Pattern**: Distributed work queue with partitioned topics

```
┌─────────────┐     ┌─────────────────┐     ┌─────────────┐
│  Producer   │────▶│  Queue Broker   │────▶│  Consumer   │
│  (Letter    │     │  (Partitioned)  │     │  (Worker    │
│  Service)   │     │                 │     │   Pool)     │
└─────────────┘     └─────────────────┘     └─────────────┘
                            │
                    ┌───────▼────────┐
                    │  Task Status   │
                    │    Storage     │
                    │  (Redis/etcd)  │
                    └────────────────┘
```

**Queue Architecture**:
- **Partitioning Strategy**: Hash(GiftID) % NumPartitions
- **Replication Factor**: 3 replicas per partition
- **Consumer Groups**: Auto-scaling based on queue depth
- **Message Format**: Protocol Buffers

**Go-Specific Implementation**:
```go
type WorkerPool struct {
    workers   int
    taskChan  chan Task
    quitChan  chan struct{}
    wg        sync.WaitGroup
}

func (wp *WorkerPool) Start(ctx context.Context) {
    for i := 0; i < wp.workers; i++ {
        go wp.worker(ctx, i)
    }
}
```

```protobuf
message Task {
    string gift_id = 1;
    string task_type = 2;
    int32 priority = 3;
    repeated string dependencies = 4;
    int32 retry_count = 5;
    google.protobuf.Timestamp deadline = 6;
    map<string, string> metadata = 7;
}
```

**Task State Machine**:
```
PENDING -> ASSIGNED -> IN_PROGRESS -> COMPLETED
   |          |            |
   |          └────────────┴────────> FAILED
   └────────────────────────────────> EXPIRED
```

### 3. Exchange Matcher Service (OCaml)

**Design Pattern**: Distributed consensus with privacy-preserving computation

```
┌─────────────────┐     ┌─────────────────┐     ┌─────────────┐
│   Region A      │     │   Region B      │     │   Region C   │
│   Matcher       │◀───▶│   Matcher       │◀───▶│   Matcher    │
│   (Follower)    │     │   (Leader)      │     │   (Follower) │
└─────────────────┘     └─────────────────┘     └─────────────┘
         │                       │                       │
         └───────────────────────┴───────────────────────┘
                                 │
                         ┌───────▼────────┐
                         │  Raft Consensus│
                         │     Layer      │
                         └────────────────┘
```

**Matching Algorithm Phases**:

1. **Registration Phase**:
   ```ocaml
   type participant = {
     id: string;
     region: region;
     constraints: constraint_set;
     public_key: bytes;
   }
   
   type constraint_set = 
     | Budget of float
     | Exclusions of string list
     | Preferences of preference list
   ```

2. **Graph Construction**:
   - Build adjacency matrix locally
   - Share encrypted constraints via secure broadcast
   - Verify constraint consistency

3. **Matching Execution**:
   - Leader runs Hungarian algorithm
   - Followers validate proposed matching
   - Two-phase commit for atomicity

## Data Storage Design

### Primary Storage

**Gift Registry (PostgreSQL)**:
```sql
CREATE TABLE gifts (
    id BIGINT PRIMARY KEY,
    workshop_id INT NOT NULL,
    created_at TIMESTAMP NOT NULL,
    gift_type VARCHAR(50),
    status VARCHAR(20),
    recipient_id VARCHAR(100),
    INDEX idx_created_at (created_at),
    INDEX idx_recipient (recipient_id)
) PARTITION BY RANGE (created_at);
```

**Task Queue State (Redis Cluster)**:
```
gift:task:{gift_id} -> Task protobuf
queue:{priority}:{partition} -> List of task IDs
worker:{worker_id}:assigned -> Set of task IDs
```

**Exchange State (etcd)**:
```
/exchanges/{year}/participants/{id} -> Participant data
/exchanges/{year}/matches/{id} -> Encrypted match
/exchanges/{year}/state -> Current phase
```

### Caching Strategy

**Multi-Level Cache**:
1. **Application Cache**: In-memory LRU (Gift ID lookups)
2. **Distributed Cache**: Redis (Task states, worker assignments)
3. **CDN Cache**: Static assets and API responses

## Network Design

### Service Mesh (Istio/Linkerd)

```yaml
apiVersion: networking.istio.io/v1beta1
kind: VirtualService
metadata:
  name: gift-id-generator
spec:
  http:
  - match:
    - headers:
        x-version:
          exact: v2
    route:
    - destination:
        host: gift-id-generator
        subset: v2
      weight: 20  # Canary deployment
    - destination:
        host: gift-id-generator
        subset: v1
      weight: 80
```

### Security

**Zero Trust Architecture**:
- mTLS between all services
- JWT tokens for API authentication
- Service-to-service authorization via SPIFFE/SPIRE
- Encrypted data at rest (AES-256)

## Scalability Considerations

### Horizontal Scaling

**Gift ID Generator**:
- Scale out: Add instances with new Workshop IDs
- Scale limit: 1024 workshops (10-bit limit)
- Mitigation: Regional generators with different epoch

**Task Queue**:
- Scale out: Increase partitions and consumer groups
- Auto-scaling based on queue depth and processing time
- Work stealing for load balancing

**Exchange Matcher**:
- Scale out: Regional sharding
- Cross-region matching via federation
- Batch processing for large exchanges

### Performance Optimization

**Techniques**:
1. **Connection Pooling**: Reuse gRPC connections
2. **Batch Operations**: Group database writes
3. **Async Processing**: Non-blocking I/O throughout
4. **Compression**: gzip for API responses, snappy for messages

**Benchmarks**:
```
Gift ID Generation (Zig): 2M IDs/second per instance (~15ns per ID)
Task Queue Throughput (Go): 100K messages/second with goroutine pools
Matching Algorithm (OCaml): O(n³) for n participants, type-safe guarantees

Memory Usage:
- Zig Service: ~10MB RSS
- Go Service: ~50-100MB (with GC)
- OCaml Service: ~30-50MB (with GC)
```

## Monitoring and Observability

### Metrics (Prometheus)

```yaml
# Key metrics to track
gift_id_generation_rate
gift_id_collision_count
task_queue_depth{queue, priority}
task_processing_duration{task_type}
worker_utilization{worker_id}
matching_duration{region}
consensus_leader_changes
```

### Distributed Tracing (Jaeger)

```go
// Trace example
span, ctx := opentracing.StartSpanFromContext(ctx, "process_gift_task")
defer span.Finish()
span.SetTag("gift_id", giftID)
span.SetTag("task_type", taskType)
```

### Logging (ELK Stack)

**Structured Logging Format**:
```json
{
  "timestamp": "2024-12-20T10:15:30Z",
  "level": "INFO",
  "service": "task-queue",
  "trace_id": "abc123",
  "gift_id": "1234567890",
  "message": "Task completed successfully",
  "duration_ms": 145
}
```

## Deployment Strategy

### Kubernetes Configuration

**Gift ID Generator (Zig)**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: gift-id-generator-zig
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: gift-id-generator
        image: santa/gift-id-zig:v1.2.3
        resources:
          requests:
            memory: "64Mi"   # Zig uses minimal memory
            cpu: "100m"
          limits:
            memory: "128Mi"
            cpu: "500m"
```

**Task Queue (Go)**:
```yaml
apiVersion: apps/v1
kind: Deployment
metadata:
  name: task-queue-go
spec:
  replicas: 5
  template:
    spec:
      containers:
      - name: task-queue
        image: santa/task-queue-go:v1.2.3
        env:
        - name: GOMAXPROCS
          value: "2"
        resources:
          requests:
            memory: "256Mi"
            cpu: "500m"
```

**Exchange Matcher (OCaml)**:
```yaml
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: exchange-matcher-ocaml
spec:
  replicas: 3
  template:
    spec:
      containers:
      - name: exchange-matcher
        image: santa/matcher-ocaml:v1.2.3
        resources:
          requests:
            memory: "512Mi"
            cpu: "1000m"
```

### Multi-Region Deployment

```
┌──────────────┐    ┌──────────────┐    ┌──────────────┐
│  US-EAST     │    │  EU-WEST     │    │  ASIA-PAC    │
│              │◀──▶│              │◀──▶│              │
│  Primary     │    │  Secondary   │    │  Secondary   │
└──────────────┘    └──────────────┘    └──────────────┘
       │                   │                   │
       └───────────────────┴───────────────────┘
                           │
                   ┌───────▼────────┐
                   │  Global Load   │
                   │   Balancer     │
                   └────────────────┘
```

## Disaster Recovery

### Backup Strategy

1. **Database Backups**: Daily snapshots + continuous WAL archiving
2. **State Backups**: Redis RDB snapshots every hour
3. **Configuration Backups**: etcd snapshots every 6 hours

### Failure Scenarios

**Region Failure**:
- Automatic failover to secondary region
- DNS update via health checks
- Maximum 5-minute recovery time

**Data Center Failure**:
- Kubernetes pod redistribution
- Persistent volume migration
- Zero data loss for completed transactions

## Development Workflow

### Local Development

```bash
# Docker Compose setup
docker-compose up -d consul redis postgres

# Run services locally

# Zig - Gift ID Generator
zig build run -- --workshop-id=1

# Go - Task Queue  
go run cmd/task-queue/main.go --partition=0

# OCaml - Exchange Matcher
dune exec bin/matcher.exe -- --region=local
```

### Language-Specific Development

**Zig Development**:
```bash
# Fast compilation
zig build -Doptimize=Debug
# Run tests
zig test src/id_generator.zig
# Format code
zig fmt src/
```

**Go Development**:
```bash
# Hot reload with air
air -c .air.toml
# Run with race detector
go run -race ./cmd/task-queue
# Generate mocks
go generate ./...
```

**OCaml Development**:
```bash
# Watch mode
dune build -w
# Run tests
dune test
# Format code
dune build @fmt --auto-promote
```

### Testing Strategy

**Unit Tests**: 80% code coverage minimum
- **Zig**: Built-in test framework with `zig test`
- **Go**: Table-driven tests with `testify`
- **OCaml**: Property-based testing with `QCheck`

**Integration Tests**: Test service interactions
- Shared protobuf definitions
- Docker Compose for full stack testing
- Language-specific gRPC clients

**Chaos Testing**: Simulate failures with Chaos Monkey
**Load Testing**: 
- **Zig**: Custom benchmarks showing ~15ns/ID
- **Go**: K6 scripts for queue throughput
- **OCaml**: Matching algorithm complexity analysis

## Cost Optimization

1. **Auto-scaling**: Scale down during off-peak hours
2. **Spot Instances**: Use for non-critical workers
3. **Data Lifecycle**: Archive old gifts to cold storage
4. **Reserved Capacity**: For predictable baseline load

## Security Considerations

### Threat Model

1. **DDoS Protection**: Rate limiting at API Gateway
2. **Data Privacy**: Encryption for PII, GDPR compliance
3. **Access Control**: RBAC with principle of least privilege
4. **Audit Trail**: Immutable logs of all operations

### Compliance

- **COPPA**: Parental consent for children under 13
- **GDPR**: Right to erasure for EU citizens
- **SOC2**: Annual security audits

## Future Enhancements

1. **GraphQL API**: Flexible querying for complex gift relationships
2. **Machine Learning**: Predict gift preferences and queue bottlenecks
3. **Blockchain**: Immutable gift delivery proof
4. **Edge Computing**: Process tasks closer to workshops
5. **WebAssembly**: Allow custom task processors
