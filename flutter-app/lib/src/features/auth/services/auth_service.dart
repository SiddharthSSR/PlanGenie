import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;
  static final GoogleSignIn _googleSignIn = GoogleSignIn.instance;
  static bool _googleInitialized = false;
  static Future<void>? _initializingGoogle;
  static const List<String> _defaultGoogleScopes = <String>['email', 'profile'];

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      return _auth.signInWithPopup(googleProvider);
    }

    await _ensureGoogleInitialized();

    try {
      final GoogleSignInAccount account =
          await _googleSignIn.authenticate();
      final GoogleSignInAuthentication tokens = account.authentication;

      if (tokens.idToken == null) {
        throw FirebaseAuthException(
          code: 'google-missing-id-token',
          message: 'Google sign-in failed to return an ID token.',
        );
      }

      final String? accessToken = await _fetchAccessToken(account);

      final OAuthCredential credential = GoogleAuthProvider.credential(
        idToken: tokens.idToken,
        accessToken: accessToken,
      );
      return _auth.signInWithCredential(credential);
    } on GoogleSignInException catch (error) {
      throw FirebaseAuthException(
        code: 'google-${error.code.name}',
        message: error.description ?? 'Google sign-in failed.',
      );
    }
  }

  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<UserCredential> createAccountWithEmail({
    required String email,
    required String password,
  }) {
    return _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  Future<PhoneSignInHandle> startPhoneNumberSignIn(
    String phoneNumber, {
    int? forceResendToken,
  }) async {
    if (kIsWeb) {
      final confirmation = await _auth.signInWithPhoneNumber(phoneNumber);
      return PhoneSignInHandle.web(confirmation);
    }

    final completer = Completer<PhoneSignInHandle>();

    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber,
      forceResendingToken: forceResendToken,
      verificationCompleted: (PhoneAuthCredential credential) async {
        if (!completer.isCompleted) {
          final userCredential = await _auth.signInWithCredential(credential);
          completer.complete(PhoneSignInHandle.completed(userCredential));
        }
      },
      verificationFailed: (FirebaseAuthException error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
      codeSent: (String verificationId, int? newResendToken) {
        if (!completer.isCompleted) {
          completer.complete(
            PhoneSignInHandle.mobile(
              verificationId: verificationId,
              resendToken: newResendToken,
            ),
          );
        }
      },
      codeAutoRetrievalTimeout: (_) {},
    );

    return completer.future;
  }

  Future<UserCredential> confirmSmsCode(
      PhoneSignInHandle handle, String smsCode) {
    if (handle.isCompleted) {
      return Future.value(handle.completedCredential!);
    }

    if (handle.confirmationResult != null) {
      return handle.confirmationResult!.confirm(smsCode);
    }

    final credential = PhoneAuthProvider.credential(
      verificationId: handle.verificationId!,
      smsCode: smsCode,
    );
    return _auth.signInWithCredential(credential);
  }

  Future<String?> _fetchAccessToken(GoogleSignInAccount account) async {
    try {
      final GoogleSignInAuthorizationClient client =
          account.authorizationClient;
      final GoogleSignInClientAuthorization? cached =
          await client.authorizationForScopes(_defaultGoogleScopes);
      if (cached != null) {
        return cached.accessToken;
      }
      final GoogleSignInClientAuthorization refreshed =
          await client.authorizeScopes(_defaultGoogleScopes);
      return refreshed.accessToken;
    } on GoogleSignInException {
      return null;
    }
  }

  static Future<void> _ensureGoogleInitialized() async {
    if (_googleInitialized) {
      return;
    }
    final Future<void>? inFlight = _initializingGoogle;
    if (inFlight != null) {
      await inFlight;
      return;
    }
    final Future<void> initialize = _googleSignIn.initialize();
    _initializingGoogle = initialize;
    try {
      await initialize;
      _googleInitialized = true;
    } finally {
      _initializingGoogle = null;
    }
  }
}

class PhoneSignInHandle {
  PhoneSignInHandle.web(ConfirmationResult confirmation)
      : confirmationResult = confirmation,
        verificationId = null,
        resendToken = null,
        completedCredential = null;

  PhoneSignInHandle.mobile({
    required this.verificationId,
    this.resendToken,
  })  : confirmationResult = null,
        completedCredential = null;

  PhoneSignInHandle.completed(UserCredential credential)
      : confirmationResult = null,
        verificationId = null,
        resendToken = null,
        completedCredential = credential;

  final ConfirmationResult? confirmationResult;
  final String? verificationId;
  final int? resendToken;
  final UserCredential? completedCredential;

  bool get isCompleted => completedCredential != null;
}
