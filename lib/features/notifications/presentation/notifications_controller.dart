import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../auth/presentation/auth_providers.dart';
import '../data/notifications_repository.dart';

final notificationsCurrentUserIdProvider = Provider<String?>((ref) {
  if (Firebase.apps.isEmpty) {
    return null;
  }
  final authState = ref.watch(authStateProvider);
  return authState.when(
    data: (user) => user?.uid,
    loading: () => FirebaseAuth.instance.currentUser?.uid,
    error: (_, _) => FirebaseAuth.instance.currentUser?.uid,
  );
});

final notificationsGatewayProvider = Provider<NotificationsGateway>((ref) {
  return FirestoreNotificationsRepository();
});

class NotificationsViewState {
  const NotificationsViewState({
    this.items = const [],
    this.isLoading = false,
    this.hasLoaded = false,
    this.isMutating = false,
    this.errorMessage,
    this.activeFilter = NotificationFilter.all,
  });

  final NotificationList items;
  final bool isLoading;
  final bool hasLoaded;
  final bool isMutating;
  final String? errorMessage;
  final NotificationFilter activeFilter;

  bool get isInitialLoading => isLoading && !hasLoaded;

  int get unreadCount => NotificationsLogic.countUnread(items);

  NotificationList get filteredItems =>
      NotificationsLogic.filterItems(items, activeFilter);

  NotificationsViewState copyWith({
    NotificationList? items,
    bool? isLoading,
    bool? hasLoaded,
    bool? isMutating,
    String? errorMessage,
    bool clearError = false,
    NotificationFilter? activeFilter,
  }) {
    return NotificationsViewState(
      items: items ?? this.items,
      isLoading: isLoading ?? this.isLoading,
      hasLoaded: hasLoaded ?? this.hasLoaded,
      isMutating: isMutating ?? this.isMutating,
      errorMessage: clearError ? null : (errorMessage ?? this.errorMessage),
      activeFilter: activeFilter ?? this.activeFilter,
    );
  }
}

class NotificationsController extends Notifier<NotificationsViewState> {
  StreamSubscription<NotificationList>? _subscription;
  String _activeUid = '';
  int _sessionToken = 0;

  @override
  NotificationsViewState build() {
    _cancelSubscription();
    _sessionToken++;
    final uid = (ref.watch(notificationsCurrentUserIdProvider) ?? '').trim();
    _activeUid = uid;

    ref.onDispose(() {
      _sessionToken++;
      _cancelSubscription();
    });

    if (uid.isEmpty) {
      return const NotificationsViewState(hasLoaded: true);
    }

    final token = _sessionToken;
    Future<void>.microtask(() => _subscribe(uid, token));
    return const NotificationsViewState(isLoading: true);
  }

  void _cancelSubscription() {
    _subscription?.cancel();
    _subscription = null;
  }

  void _subscribe(String userId, int token) {
    if (token != _sessionToken || _activeUid != userId) return;
    _cancelSubscription();

    final gateway = ref.read(notificationsGatewayProvider);
    _subscription = gateway.watchNotifications(userId: userId).listen(
      (items) {
        if (token != _sessionToken) return;
        state = state.copyWith(
          items: items,
          isLoading: false,
          hasLoaded: true,
          clearError: true,
        );
      },
      onError: (Object error) {
        if (token != _sessionToken) return;
        state = state.copyWith(
          isLoading: false,
          hasLoaded: true,
          errorMessage: NotificationsErrorMapper.map(error),
        );
      },
    );
  }

  Future<void> refresh() async {
    if (_activeUid.isEmpty) return;
    _sessionToken++;
    final token = _sessionToken;
    state = state.copyWith(isLoading: true, clearError: true);
    _subscribe(_activeUid, token);
  }

  void setFilter(NotificationFilter filter) {
    if (state.activeFilter == filter) return;
    state = state.copyWith(activeFilter: filter);
  }

  Future<String?> markAsRead(String notificationId) async {
    final cleanUid = _activeUid;
    final cleanId = notificationId.trim();
    if (cleanUid.isEmpty || cleanId.isEmpty) return null;

    NotificationItem? target;
    for (final item in state.items) {
      if (item.id == cleanId) {
        target = item;
        break;
      }
    }
    if (target == null || target.isRead) return null;

    final token = _sessionToken;
    final previousItems = List<NotificationItem>.from(state.items);
    final nextItems = previousItems.map((item) {
      if (item.id != cleanId) return item;
      return item.copyWith(isRead: true);
    }).toList();

    state = state.copyWith(items: nextItems);

    try {
      await ref.read(notificationsGatewayProvider).markAsRead(
            userId: cleanUid,
            notificationId: cleanId,
          );
      return null;
    } catch (e) {
      if (token == _sessionToken) {
        state = state.copyWith(items: previousItems);
      }
      return NotificationsErrorMapper.map(e);
    }
  }

  Future<String?> markAllAsRead() async {
    final cleanUid = _activeUid;
    if (cleanUid.isEmpty || state.isMutating) return null;

    final unreadIds = state.items
        .where((item) => !item.isRead)
        .map((item) => item.id)
        .toList();
    if (unreadIds.isEmpty) return null;

    final token = _sessionToken;
    final previousItems = List<NotificationItem>.from(state.items);
    final nextItems =
        previousItems.map((item) => item.copyWith(isRead: true)).toList();

    state = state.copyWith(items: nextItems, isMutating: true);

    try {
      await ref.read(notificationsGatewayProvider).markAllAsRead(
            userId: cleanUid,
            unreadNotificationIds: unreadIds,
          );
      if (token == _sessionToken) {
        state = state.copyWith(isMutating: false);
      }
      return null;
    } catch (e) {
      if (token == _sessionToken) {
        state = state.copyWith(items: previousItems, isMutating: false);
      }
      return NotificationsErrorMapper.map(e);
    }
  }

  Future<String?> deleteNotification(String notificationId) async {
    final cleanUid = _activeUid;
    final cleanId = notificationId.trim();
    if (cleanUid.isEmpty || cleanId.isEmpty) return null;

    final token = _sessionToken;
    final previousItems = List<NotificationItem>.from(state.items);
    final nextItems =
        previousItems.where((item) => item.id != cleanId).toList();

    state = state.copyWith(items: nextItems);

    try {
      await ref.read(notificationsGatewayProvider).deleteNotification(
            userId: cleanUid,
            notificationId: cleanId,
          );
      return null;
    } catch (e) {
      if (token == _sessionToken) {
        state = state.copyWith(items: previousItems);
      }
      return NotificationsErrorMapper.map(e);
    }
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsViewState>(
  NotificationsController.new,
);

final unreadNotificationsCountProvider = Provider<int>((ref) {
  return ref.watch(
    notificationsControllerProvider.select((view) => view.unreadCount),
  );
});