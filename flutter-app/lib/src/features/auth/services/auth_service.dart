import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

class AuthService {
  AuthService(this._auth);

  final FirebaseAuth _auth;

  Future<UserCredential> signInWithGoogle() async {
    if (kIsWeb) {
      final googleProvider = GoogleAuthProvider();
      return _auth.signInWithPopup(googleProvider);
    }

    final googleSignIn = GoogleSignIn();
    final googleUser = await googleSignIn.signIn();
    if (googleUser == null) {
      throw FirebaseAuthException(
        code: 'ERROR_ABORTED_BY_USER',
        message: 'Sign-in aborted before completion.',
      );
    }

    final googleAuth = await googleUser.authentication;
    final credential = GoogleAuthProvider.credential(
      accessToken: googleAuth.accessToken,
      idToken: googleAuth.idToken,
    );
    return _auth.signInWithCredential(credential);
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
