import 'dart:typed_data';
import 'package:flutter/material.dart';

enum NavSection { home, map, vpn, vpnConfigs, chatList, messenger }

class NavBarController extends ChangeNotifier {
  final navigatorKey = GlobalKey<NavigatorState>();
  final routeObserver = RouteObserver<PageRoute<dynamic>>();

  bool _visible = false;
  NavSection _section = NavSection.home;
  Uint8List? _avatarBytes;
  int _homeTabIndex = 0;
  void Function(int)? _switchTab;
  int _unreadCount = 0;

  bool _mapSharing = false;
  bool _mapHasLocation = false;
  VoidCallback? _mapToggle;
  VoidCallback? _mapAddEvent;
  VoidCallback? _mapCenter;

  VoidCallback? _vpnSplitTunnel;
  VoidCallback? _vpnConfigs;

  // vpnConfigs section
  VoidCallback? _vpnConfigsAdd;
  VoidCallback? _savedVpnSplitTunnel;
  VoidCallback? _savedVpnConfigs;

  // chatList section
  ValueChanged<String>? _chatSearch;
  VoidCallback? _chatAdd;

  // messenger section
  TextEditingController? _messengerController;
  VoidCallback? _messengerSend;
  VoidCallback? _messengerAttach;
  VoidCallback? _messengerMicTap;
  void Function(double)? _messengerMicStart;
  void Function(double)? _messengerMicMove;
  VoidCallback? _messengerMicEnd;
  bool _messengerVideoMode = false;
  bool _messengerIsRecording = false;
  bool _messengerRecordingLocked = false;
  int _messengerRecordingSeconds = 0;
  bool _messengerBusy = false;
  String? _messengerReplyText;
  String? _messengerReplySender;
  bool _messengerIsEditing = false;
  VoidCallback? _messengerCancelReply;
  VoidCallback? _messengerCancelEdit;

  bool get visible => _visible;
  NavSection get section => _section;
  Uint8List? get avatarBytes => _avatarBytes;
  int get homeTabIndex => _homeTabIndex;
  int get unreadCount => _unreadCount;
  bool get mapSharing => _mapSharing;
  bool get mapHasLocation => _mapHasLocation;
  VoidCallback? get mapToggle => _mapToggle;
  VoidCallback? get mapAddEvent => _mapAddEvent;
  VoidCallback? get mapCenter => _mapCenter;
  VoidCallback? get vpnSplitTunnel => _vpnSplitTunnel;
  VoidCallback? get vpnConfigs => _vpnConfigs;
  VoidCallback? get vpnConfigsAdd => _vpnConfigsAdd;
  ValueChanged<String>? get chatSearch => _chatSearch;
  VoidCallback? get chatAdd => _chatAdd;

  TextEditingController? get messengerController => _messengerController;
  VoidCallback? get messengerSend => _messengerSend;
  VoidCallback? get messengerAttach => _messengerAttach;
  VoidCallback? get messengerMicTap => _messengerMicTap;
  void Function(double)? get messengerMicStart => _messengerMicStart;
  void Function(double)? get messengerMicMove => _messengerMicMove;
  VoidCallback? get messengerMicEnd => _messengerMicEnd;
  bool get messengerVideoMode => _messengerVideoMode;
  bool get messengerIsRecording => _messengerIsRecording;
  bool get messengerRecordingLocked => _messengerRecordingLocked;
  int get messengerRecordingSeconds => _messengerRecordingSeconds;
  bool get messengerBusy => _messengerBusy;
  String? get messengerReplyText => _messengerReplyText;
  String? get messengerReplySender => _messengerReplySender;
  bool get messengerIsEditing => _messengerIsEditing;
  VoidCallback? get messengerCancelReply => _messengerCancelReply;
  VoidCallback? get messengerCancelEdit => _messengerCancelEdit;

  void show() { _visible = true; notifyListeners(); }
  void hide() { _visible = false; notifyListeners(); }

  void setAvatarBytes(Uint8List? bytes) { _avatarBytes = bytes; notifyListeners(); }
  void setUnreadCount(int count) { _unreadCount = count; notifyListeners(); }

  void registerTabSwitch(void Function(int) fn) { _switchTab = fn; }

  void switchTab(int index) {
    _homeTabIndex = index;
    _switchTab?.call(index);
    notifyListeners();
  }

  void enterMap({
    required bool sharing,
    required bool hasLocation,
    required VoidCallback toggle,
    required VoidCallback addEvent,
    required VoidCallback center,
  }) {
    _section = NavSection.map;
    _mapSharing = sharing;
    _mapHasLocation = hasLocation;
    _mapToggle = toggle;
    _mapAddEvent = addEvent;
    _mapCenter = center;
    notifyListeners();
  }

  void updateMapState({required bool sharing, required bool hasLocation}) {
    if (_section != NavSection.map) return;
    _mapSharing = sharing;
    _mapHasLocation = hasLocation;
    notifyListeners();
  }

  void enterVpn({required VoidCallback splitTunnel, required VoidCallback configs}) {
    _section = NavSection.vpn;
    _vpnSplitTunnel = splitTunnel;
    _vpnConfigs = configs;
    notifyListeners();
  }

  void enterVpnConfigs({required VoidCallback onAdd}) {
    _savedVpnSplitTunnel = _vpnSplitTunnel;
    _savedVpnConfigs = _vpnConfigs;
    _vpnConfigsAdd = onAdd;
    _section = NavSection.vpnConfigs;
    notifyListeners();
  }

  void exitVpnConfigs() {
    _section = NavSection.vpn;
    _vpnSplitTunnel = _savedVpnSplitTunnel;
    _vpnConfigs = _savedVpnConfigs;
    _vpnConfigsAdd = null;
    notifyListeners();
  }

  void enterChatList({
    required ValueChanged<String> onSearch,
    required VoidCallback onAdd,
  }) {
    _chatSearch = onSearch;
    _chatAdd = onAdd;
    _section = NavSection.chatList;
    notifyListeners();
  }

  void exitChatList() {
    _section = NavSection.home;
    _chatSearch = null;
    _chatAdd = null;
    notifyListeners();
  }

  void enterMessenger({
    required TextEditingController controller,
    required VoidCallback onSend,
    required VoidCallback onAttach,
    required VoidCallback onMicTap,
    required void Function(double) onMicStart,
    required void Function(double) onMicMove,
    required VoidCallback onMicEnd,
  }) {
    _messengerController = controller;
    _messengerSend = onSend;
    _messengerAttach = onAttach;
    _messengerMicTap = onMicTap;
    _messengerMicStart = onMicStart;
    _messengerMicMove = onMicMove;
    _messengerMicEnd = onMicEnd;
    _section = NavSection.messenger;
    notifyListeners();
  }

  void exitMessenger() {
    _section = NavSection.home;
    _messengerController = null;
    _messengerSend = null;
    _messengerAttach = null;
    _messengerMicTap = null;
    _messengerMicStart = null;
    _messengerMicMove = null;
    _messengerMicEnd = null;
    _messengerVideoMode = false;
    _messengerIsRecording = false;
    _messengerRecordingLocked = false;
    _messengerRecordingSeconds = 0;
    _messengerBusy = false;
    _messengerReplyText = null;
    _messengerReplySender = null;
    _messengerIsEditing = false;
    _messengerCancelReply = null;
    _messengerCancelEdit = null;
    notifyListeners();
  }

  void updateMessengerRecording({
    required bool isRecording,
    bool locked = false,
    int seconds = 0,
    bool videoMode = false,
  }) {
    _messengerIsRecording = isRecording;
    _messengerRecordingLocked = locked;
    _messengerRecordingSeconds = seconds;
    _messengerVideoMode = videoMode;
    notifyListeners();
  }

  void updateMessengerBanners({
    String? replyText,
    String? replySender,
    VoidCallback? onCancelReply,
    bool isEditing = false,
    VoidCallback? onCancelEdit,
  }) {
    _messengerReplyText = replyText;
    _messengerReplySender = replySender;
    _messengerCancelReply = onCancelReply;
    _messengerIsEditing = isEditing;
    _messengerCancelEdit = onCancelEdit;
    notifyListeners();
  }

  void setMessengerBusy(bool busy) {
    _messengerBusy = busy;
    notifyListeners();
  }

  void exitSection() {
    if (_section == NavSection.home) return;
    _section = NavSection.home;
    _mapToggle = null;
    _mapAddEvent = null;
    _mapCenter = null;
    _vpnSplitTunnel = null;
    _vpnConfigs = null;
    _vpnConfigsAdd = null;
    _chatSearch = null;
    _chatAdd = null;
    _messengerController = null;
    _messengerSend = null;
    _messengerAttach = null;
    _messengerMicTap = null;
    _messengerMicStart = null;
    _messengerMicMove = null;
    _messengerMicEnd = null;
    _messengerVideoMode = false;
    _messengerIsRecording = false;
    _messengerRecordingLocked = false;
    _messengerRecordingSeconds = 0;
    _messengerBusy = false;
    _messengerReplyText = null;
    _messengerReplySender = null;
    _messengerIsEditing = false;
    _messengerCancelReply = null;
    _messengerCancelEdit = null;
    notifyListeners();
  }

  void goBack() => navigatorKey.currentState?.pop();

  void pushRoute(Route<dynamic> route) => navigatorKey.currentState?.push(route);
}
