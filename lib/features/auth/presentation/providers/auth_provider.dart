import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/auth_repository.dart';

/// Exposes the Firebase Auth stream so the UI can react to sign-in/out.
final authStateProvider = StreamProvider<User?>(
  (ref) => FirebaseAuth.instance.authStateChanges(),
);

/// Provides access to the [AuthRepository].
final authRepositoryProvider = Provider<AuthRepository>(
  (ref) => AuthRepository(),
);
