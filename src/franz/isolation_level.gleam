/// Controls the visibility of transactional records when consuming messages.
pub type IsolationLevel {
  /// Only return committed transactional records.
  ReadCommitted
  /// Return all records including uncommitted transactions.
  ReadUncommitted
}
