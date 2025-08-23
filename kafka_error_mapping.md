# Kafka Error Mapping for Franz Library

## Currently Implemented in Franz

The following error types are currently defined in `src/franz.gleam`:

1. `UnknownError` - Generic unknown error
2. `ClientDown` - Client process is down
3. `UnknownTopicOrPartition` - Topic or partition doesn't exist (maps to Kafka error code 3)
4. `ProducerDown` - Producer process is down
5. `TopicAlreadyExists` - Topic already exists (maps to Kafka error code 36)
6. `ConsumerNotFound(String)` - Consumer not found for topic
7. `ProducerNotFound(String, Int)` - Producer not found for topic/partition
8. `OffsetOutOfRange` - Offset is out of range (maps to Kafka error code 1)

## Missing Kafka Protocol Error Codes

The following Kafka protocol error codes are not yet mapped in Franz:

### Critical Errors (Should be implemented)
- Code 2: `CORRUPT_MESSAGE` - Message failed CRC checksum
- Code 4: `INVALID_FETCH_SIZE` - Invalid fetch size
- Code 5: `LEADER_NOT_AVAILABLE` - No leader during election
- Code 6: `NOT_LEADER_OR_FOLLOWER` - Broker is not leader/replica
- Code 7: `REQUEST_TIMED_OUT` - Request timed out
- Code 8: `BROKER_NOT_AVAILABLE` - Broker not available
- Code 9: `REPLICA_NOT_AVAILABLE` - Replica not available
- Code 10: `MESSAGE_TOO_LARGE` - Message exceeds max size
- Code 13: `NETWORK_EXCEPTION` - Network exception

### Coordinator/Group Errors
- Code 14: `COORDINATOR_LOAD_IN_PROGRESS` - Coordinator loading
- Code 15: `COORDINATOR_NOT_AVAILABLE` - Coordinator not available
- Code 16: `NOT_COORDINATOR` - Not the coordinator
- Code 22: `ILLEGAL_GENERATION` - Illegal generation
- Code 23: `INCONSISTENT_GROUP_PROTOCOL` - Inconsistent group protocol
- Code 24: `INVALID_GROUP_ID` - Invalid group ID
- Code 25: `UNKNOWN_MEMBER_ID` - Unknown member ID
- Code 26: `INVALID_SESSION_TIMEOUT` - Invalid session timeout
- Code 27: `REBALANCE_IN_PROGRESS` - Rebalance in progress
- Code 28: `INVALID_COMMIT_OFFSET_SIZE` - Invalid commit offset size

### Authorization Errors
- Code 29: `TOPIC_AUTHORIZATION_FAILED` - Topic authorization failed
- Code 30: `GROUP_AUTHORIZATION_FAILED` - Group authorization failed
- Code 31: `CLUSTER_AUTHORIZATION_FAILED` - Cluster authorization failed

### Configuration/Validation Errors
- Code 17: `INVALID_TOPIC_EXCEPTION` - Invalid topic
- Code 18: `RECORD_LIST_TOO_LARGE` - Record list too large
- Code 19: `NOT_ENOUGH_REPLICAS` - Not enough replicas
- Code 20: `NOT_ENOUGH_REPLICAS_AFTER_APPEND` - Not enough replicas after append
- Code 21: `INVALID_REQUIRED_ACKS` - Invalid required acks
- Code 32: `INVALID_TIMESTAMP` - Invalid timestamp
- Code 37: `INVALID_PARTITIONS` - Invalid partitions
- Code 38: `INVALID_REPLICATION_FACTOR` - Invalid replication factor
- Code 39: `INVALID_REPLICA_ASSIGNMENT` - Invalid replica assignment
- Code 40: `INVALID_CONFIG` - Invalid configuration

### SASL/Security Errors
- Code 33: `UNSUPPORTED_SASL_MECHANISM` - Unsupported SASL mechanism
- Code 34: `ILLEGAL_SASL_STATE` - Illegal SASL state

### Version/Controller Errors
- Code 11: `STALE_CONTROLLER_EPOCH` - Stale controller epoch
- Code 12: `OFFSET_METADATA_TOO_LARGE` - Offset metadata too large
- Code 35: `UNSUPPORTED_VERSION` - Unsupported version
- Code 41: `NOT_CONTROLLER` - Not the controller

## Recommended Implementation Priority

### High Priority (Common in production)
1. `REQUEST_TIMED_OUT` (7)
2. `LEADER_NOT_AVAILABLE` (5)
3. `NOT_LEADER_OR_FOLLOWER` (6)
4. `BROKER_NOT_AVAILABLE` (8)
5. `REBALANCE_IN_PROGRESS` (27)
6. `NETWORK_EXCEPTION` (13)
7. `MESSAGE_TOO_LARGE` (10)

### Medium Priority (Authorization & Configuration)
1. `TOPIC_AUTHORIZATION_FAILED` (29)
2. `GROUP_AUTHORIZATION_FAILED` (30)
3. `INVALID_GROUP_ID` (24)
4. `INVALID_CONFIG` (40)
5. `COORDINATOR_NOT_AVAILABLE` (15)

### Low Priority (Less common or handled internally by brod)
- Controller epoch errors
- SASL errors
- Replica assignment errors