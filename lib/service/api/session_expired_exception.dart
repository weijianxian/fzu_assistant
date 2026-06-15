class SessionExpiredException implements Exception {
  const SessionExpiredException();

  @override
  String toString() =>
      'SessionExpiredException: session expired, re-login required';
}
