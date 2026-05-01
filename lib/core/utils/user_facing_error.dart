String remediationMessageForError(Object error) {
  final message = error.toString().toLowerCase();

  if (message.contains('timeout') || message.contains('socket')) {
    return 'Connection timed out. Verify your Wi-Fi/VPN, ensure the device is online, and retry.';
  }

  if (message.contains('permission') || message.contains('unauthorized')) {
    return 'Permission issue detected. Re-authenticate your account and confirm driver credentials.';
  }

  if (message.contains('offline') || message.contains('network')) {
    return 'Device appears offline. Confirm power, check local network reachability, then refresh.';
  }

  if (message.contains('invalid') || message.contains('format')) {
    return 'Invalid configuration detected. Review IP/MAC/model fields and try again.';
  }

  return 'Something went wrong while processing this action. Retry now or open Developer Mode diagnostics.';
}
