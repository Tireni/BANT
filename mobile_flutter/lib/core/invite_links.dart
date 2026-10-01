String? bantInviteTokenFromUri(Uri uri) {
  if (uri.scheme == 'bant' && uri.host == 'invite') {
    return uri.pathSegments.isNotEmpty ? uri.pathSegments.first : null;
  }

  if ((uri.scheme == 'https' || uri.scheme == 'http') &&
      uri.host == 'bant-demo.vercel.app' &&
      uri.pathSegments.length >= 2 &&
      uri.pathSegments.first == 'r') {
    return uri.pathSegments[1];
  }

  return null;
}
