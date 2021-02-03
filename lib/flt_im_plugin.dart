import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart';

class FltImPlugin {
  final MethodChannel _methodChannel;
  final EventChannel _eventChannel;
  static FltImPlugin _instance;

  factory FltImPlugin() {
    if (_instance == null) {
      final MethodChannel methodChannel = const MethodChannel('flt_im_plugin');
      final EventChannel eventChannel = const EventChannel('flt_im_plugin_event');
      _instance = FltImPlugin.private(methodChannel, eventChannel);
    }
    return _instance;
  }
  FltImPlugin.private(this._methodChannel, this._eventChannel);

  Stream<dynamic> _listener;

  Stream<dynamic> get onBroadcast {
    if (_listener == null) {
      _listener = _eventChannel.receiveBroadcastStream().map((event) {
        return event;
      });
    }
    return _listener;
  }

  /// 初始化
  Future<Map> init({@required String host, @required String apiURL}) {
    return _methodChannel.invokeMapMethod('init', {'host': host, 'apiURL': apiURL});
  }

  /// 登录
  /// uid 用户id（数字），
  /// token: 用户token,
  Future<Map> login({@required String uid, String token}) async {
    return _methodChannel.invokeMapMethod('login', {'uid': uid, 'token': token});
  }

  Future<Map> createConversion({
    @required String currentUID,
    @required String peerUID,
    bool secret = false,
  }) async {
    return _methodChannel.invokeMethod('createConversion', {
      "currentUID": currentUID,
      "peerUID": peerUID,
      "secret": secret ? 1 : 0,
    });
  }

  Future<Map> loadData({String messageID}) async {
    return _methodChannel.invokeMapMethod('loadData', {
      'messageID': messageID,
    });
  }

  Future<Map> loadEarlierData({String messageID}) {
    return _methodChannel.invokeMapMethod('loadEarlierData', {
      'messageID': messageID,
    });
  }

  Future<Map> loadLateData({String messageID}) {
    return _methodChannel.invokeMapMethod('loadLateData', {
      'messageID': messageID,
    });
  }

  /// 登出
  Future<Map> logout() async {
    return _methodChannel.invokeMethod('logout');
  }

  Future<Map> sendTextMessage({bool secret, String sender, String receiver, String rawContent}) async {
    return sendMessage(type: 1, message: {
      'sender': sender,
      'receiver': receiver,
      'rawContent': rawContent,
      'secret': secret ? 1 : 0,
    });
  }

  Future<Map> sendImageMessage({bool secret, String sender, String receiver, Uint8List image}) async {
    return sendMessage(type: 2, message: {
      'sender': sender,
      'receiver': receiver,
      'image': image,
      'secret': secret ? 1 : 0,
    });
  }

  Future<Map> sendVideoMessage({
    String path,
    String thumbPath, // android 必传
    bool secret,
    String sender,
    String receiver,
  }) async {
    return sendMessage(type: 12, message: {
      'sender': sender,
      'receiver': receiver,
      'secret': secret ? 1 : 0,
      'path': path,
      'thumbPath': thumbPath,
    });
  }

  Future<Map> sendAudioMessage({
    String path,
    int second, // ios 必传
    bool secret,
    String sender,
    String receiver,
  }) async {
    return sendMessage(type: 3, message: {
      'sender': sender,
      'receiver': receiver,
      'secret': secret ? 1 : 0,
      'path': path,
      'second': second,
    });
  }

  Future<Map> sendLocationMessage({
    double latitude,
    double longitude,
    String address,
    bool secret,
    String sender,
    String receiver,
  }) async {
    return sendMessage(type: 4, message: {
      'sender': sender,
      'receiver': receiver,
      'secret': secret ? 1 : 0,
      'latitude': latitude,
      'longitude': longitude,
      'address': address,
    });
  }

  /// type: 1-text, 2-image, 3-audio, 4-location, 5-group-noti, 6-link
  Future<Map> sendMessage({
    int type,
    Map message,
  }) async {
    return _methodChannel.invokeMapMethod('sendMessage', {
      'type': type,
      'message': message,
    });
  }

  Future<Map> getLocalCacheImage({String url}) async {
    return _methodChannel.invokeMapMethod('getLocalCacheImage', {
      'url': url,
    });
  }
  Future<Map> clearReadCount({String cid}) async {
    return _methodChannel.invokeMapMethod('clearReadCount', {
      'cid': cid,
    });
  }
  Future<Map> clearGroupReadCount({String cid}) async {
    return _methodChannel.invokeMapMethod('clearGroupReadCount', {
      'cid': cid,
    });
  }
  Future<Map> getLocalMediaURL({String url}) async {
    return _methodChannel.invokeMapMethod('getLocalMediaURL', {
      'url': url,
    });
  }

  Future<Map> getConversations() async {
    return _methodChannel.invokeMapMethod('getConversations', {});
  }

  Future<Map> deleteConversation({String cid}) async {
    return _methodChannel.invokeMapMethod('deleteConversation', {'cid': cid});
  }
}
