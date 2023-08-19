class EndOfStreamException implements Exception {
  final Exception? innerException;

  const EndOfStreamException([this.innerException]);
}
