import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:get/get.dart';
import 'package:google_sign_in/google_sign_in.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/users_repo.dart';
import '../services/deep_link_service.dart';

class AuthController extends GetxController {
  final RxBool isLoading = false.obs;
  final Rxn<User> currentUser = Rxn<User>();
  final Rxn<Map<String, dynamic>> userProfile = Rxn<Map<String, dynamic>>();
  late StreamSubscription<AuthState> _authSubscription;
  final UsersRepository _usersRepo = UsersRepository();

  @override
  void onInit() {
    super.onInit();
    _initializeAuth();
  }

  @override
  void onClose() {
    _authSubscription.cancel();
    super.onClose();
  }

  void _initializeAuth() {
    _authSubscription = Supabase.instance.client.auth.onAuthStateChange.listen((
      data,
    ) async {
      final event = data.event;
      final session = data.session;

      if (event == AuthChangeEvent.signedIn && session?.user != null) {
        currentUser.value = session!.user;
        await _loadUserProfile(session.user);
        Get.offAllNamed('/home');

        if (Get.isRegistered<DeepLinkService>()) {
          Get.find<DeepLinkService>().tryNavigatePendingMoment();
        }
      } else if (event == AuthChangeEvent.signedOut) {
        currentUser.value = null;
        userProfile.value = null;
        Get.offAllNamed('/login');
      }
    });

    // Check current user
    final user = Supabase.instance.client.auth.currentUser;
    if (user != null) {
      currentUser.value = user;
      _loadUserProfile(user);
    }
  }

  /// Load user profile from public users table
  Future<void> _loadUserProfile(User user) async {
    try {
      var profile = await _usersRepo.getUserProfile(user.id);

      if (profile == null) {
        String? firstname;
        String? lastname;

        final fullName =
            user.userMetadata?['full_name']?.toString() ??
            user.userMetadata?['name']?.toString();
        if (fullName?.isNotEmpty == true) {
          final nameParts = fullName!.split(' ');
          firstname = nameParts.first;
          if (nameParts.length > 1) {
            lastname = nameParts.sublist(1).join(' ');
          }
        }

        final avatarUrl =
            user.userMetadata?['avatar_url']?.toString() ??
            user.userMetadata?['picture']?.toString();

        profile = await _usersRepo.upsertUserProfile(
          userId: user.id,
          email: user.email ?? '',
          firstname: firstname,
          lastname: lastname,
          avatarUrl: avatarUrl,
        );
      }

      if (profile != null) {
        userProfile.value = profile;
      }
    } catch (e) {
      print('❌ Error loading user profile: $e');
    }
  }

  Future<void> signInWithGoogle() async {
    try {
      isLoading.value = true;

      const webClientId =
          '888544525684-mgbrefvr3lhedh00io4b9fv5vg552if5.apps.googleusercontent.com';

      const iosClientId =
          '888544525684-u2vk8nn47sg2t7pdrifir53jee9ad4ih.apps.googleusercontent.com';

      final GoogleSignIn signIn = GoogleSignIn.instance;

      // Sign out first to clear any cached credentials
      await signIn.signOut();

      // Initialize GoogleSignIn with platform-specific configuration
      if (kIsWeb) {
        // Web platform - only use webClientId
        unawaited(signIn.initialize(clientId: webClientId));
      } else if (defaultTargetPlatform == TargetPlatform.iOS) {
        // iOS platform - use iOS client ID
        unawaited(
          signIn.initialize(clientId: iosClientId, serverClientId: webClientId),
        );
      } else {
        // Android platform - try using web client ID for server-side auth
        unawaited(signIn.initialize(serverClientId: webClientId));
      }

      // Perform the sign in with error handling
      final googleAccount = await signIn.authenticate();

      final googleAuthorization = await googleAccount.authorizationClient
          .authorizationForScopes(['email', 'profile']);
      final googleAuthentication = googleAccount.authentication;
      final idToken = googleAuthentication.idToken;
      final accessToken = googleAuthorization?.accessToken;

      if (idToken == null) {
        throw 'No ID Token found.';
      }

      print('🔐 Signing in to Supabase with Google credentials...');

      await Supabase.instance.client.auth.signInWithIdToken(
        provider: OAuthProvider.google,
        idToken: idToken,
        accessToken: accessToken,
      );

      Get.snackbar(
        'Success',
        'Successfully signed in with Google!',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.green,
        colorText: Colors.white,
      );
    } on PlatformException catch (e) {
      print(
        '❌ Platform error signing in with Google: ${e.code} - ${e.message}',
      );

      // Handle specific error codes
      if (e.code == 'sign_in_canceled') {
        print('⚠️ User canceled Google sign-in');
        // Don't show error for user cancellation
        return;
      } else if (e.code == 'sign_in_failed') {
        Get.snackbar(
          'Sign In Failed',
          'Google sign-in failed. Please try again.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else if (e.code == 'network_error') {
        Get.snackbar(
          'Network Error',
          'Please check your internet connection and try again.',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 3),
        );
      } else {
        Get.snackbar(
          'Error',
          'Failed to sign in: ${e.message}',
          snackPosition: SnackPosition.TOP,
          backgroundColor: Colors.red,
          colorText: Colors.white,
          duration: const Duration(seconds: 5),
        );
      }
    } catch (e) {
      print('❌ Error signing in with Google: $e');
      Get.snackbar(
        'Error',
        'Failed to sign in with Google. Please try again.',
        snackPosition: SnackPosition.TOP,
        backgroundColor: Colors.red,
        colorText: Colors.white,
        duration: const Duration(seconds: 5),
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> signOut() async {
    try {
      isLoading.value = true;
      await Supabase.instance.client.auth.signOut();
    } catch (e) {
      Get.snackbar(
        'Error',
        'Failed to sign out: ${e.toString()}',
        snackPosition: SnackPosition.TOP,
      );
    } finally {
      isLoading.value = false;
    }
  }

  Future<void> refreshUserProfile() async {
    final user = currentUser.value;
    if (user != null) {
      await _loadUserProfile(user);
    }
  }

  // =================== GETTERS ===================

  bool get isSignedIn => currentUser.value != null;

  String? get userName {
    final profile = userProfile.value;
    if (profile != null) {
      final firstName = profile['firstname'];
      final lastName = profile['lastname'];
      if (firstName != null && lastName != null) {
        return '$firstName $lastName';
      } else if (firstName != null) {
        return firstName;
      } else if (profile['username'] != null) {
        return profile['username'];
      }
    }
    return currentUser.value?.email?.split('@').first;
  }

  String? get userEmail =>
      userProfile.value?['email'] ?? currentUser.value?.email;

  String? get userAvatar => userProfile.value?['avatar'];

  String? get userId => currentUser.value?.id;
}
