import 'dart:typed_data';

import 'package:flt_im_plugin_example/logger.dart';

import 'package:flutter/material.dart';
import 'package:flt_im_plugin/flt_im_plugin.dart';
import 'package:flt_im_plugin/message.dart';
import 'package:flt_im_plugin/value_util.dart';
import 'package:oktoast/oktoast.dart';
import 'response.dart';

class _Params {
  String peerUID;
  String peerName;
  String peerAvatar;
  bool secret; //点对点加密
  int state; //加密会话的状态

  String currentUID;

  _Params.fromMap(Map json) {
    peerUID = ValueUtil.toStr(json['peerUID']);
    peerName = ValueUtil.toStr(json['peerName']);
    peerAvatar = ValueUtil.toStr(json['peerAvatar']);
    secret = ValueUtil.toBool(json['secret']);
    state = ValueUtil.toInt(json['state']);
    currentUID = ValueUtil.toStr(json['currentUID']);
  }
}

class PeerViewModel extends ChangeNotifier {
  final _Params params;

  final FltImPlugin im = FltImPlugin();

  String text;

  List<Message> messages = [];

  PeerViewModel({@required Map params}) : params = _Params.fromMap(params) {
    // 创建会话
    listenNative();
    setup();
  }

  void setup() async {
    var res = await im.createConversion(
      currentUID: params.currentUID,
      peerUID: params.peerUID,
    );
    logger.d(res);
    Map response = await im.loadData();
    logger.d(response);
    messages = ValueUtil.toArr(response["data"]).map((e) => Message.fromMap(ValueUtil.toMap(e))).toList();
    notifyListeners();
  }

  Future<Uint8List> getLocalCacheImage({String url}) async {
    Map result = await im.getLocalCacheImage(url: url);
    NativeResponse response = NativeResponse.fromMap(result);
    return response.data;
  }

  Future<String> getLocalMediaURL({String url}) async {
    Map result = await im.getLocalMediaURL(url: url);
    NativeResponse response = NativeResponse.fromMap(result);
    return response.data;
  }

  sendTextMessage() async {
    if (text == null || text.length == 0) {
      showToast('输入内容不能为空');
      return;
    }
    Map result = await im.sendTextMessage(
      secret: false,
      sender: params.currentUID,
      receiver: params.peerUID,
      rawContent: text ?? 'hello world',
    );
    text = '';
    logger.d(result);
    insertMessage(result);
  }

  sendImageMessage(Uint8List image) async {
    Map result = await im.sendImageMessage(
      secret: false,
      sender: params.currentUID,
      receiver: params.peerUID,
      image: image,
    );
    logger.d(result);
    insertMessage(result);
  }

  sendVideoMessage(String path) async {
    Map result = await im.sendVideoMessage(
      secret: false,
      sender: params.currentUID,
      receiver: params.peerUID,
      path: path,
    );
    logger.d(result);
    insertMessage(result);
  }

  sendAudioMessage({String path, int second}) async {
    Map result = await im.sendAudioMessage(
      secret: false,
      sender: params.currentUID,
      receiver: params.peerUID,
      path: path,
      second: second,
    );
    logger.d(result);
    insertMessage(result);
  }

  sendLocationMessage({double latitude, double longitude, String address}) async {
    Map result = await im.sendLocationMessage(
      secret: false,
      sender: params.currentUID,
      receiver: params.peerUID,
      latitude: latitude,
      longitude: longitude,
      address: address,
    );
    logger.d(result);
    insertMessage(result);
  }

  logout() {
    //im.logout();
  }

  @override
  void dispose() {
    logout();
    super.dispose();
  }

  insertMessage(Map result) {
    NativeResponse response = NativeResponse.fromMap(result);
    Message message = Message.fromMap(response.data);
    messages.insert(0, message);
    notifyListeners();
  }

  //// 原生调用 flutter 模块
  listenNative() {
    im.onBroadcast.listen((event) {
      NativeResponse response = NativeResponse.fromMap(event);
      Map data = response.data;
      String type = ValueUtil.toStr(data['type']);
      var result = data['result'];
      if (response.code == 0) {
        if (type == 'onConnectState') {
           onConnectState(result);
        } else if (type == 'onPeerMessageACK') {
          int error = ValueUtil.toInt(data['error']);
          onPeerMessageACK(result, error);
        } else if (type == 'onPeerMessage') {
          onPeerMessage(result);
        } else if (type == 'onPeerSecretMessage') {
          onPeerSecretMessage(result);
        } else if (type == 'onImageUploadSuccess') {
          String url = ValueUtil.toStr(data['URL']);
          onImageUploadSuccess(result, url);
        } else if (type == 'onAudioDownloadSuccess') {
          onAudioDownloadSuccess(result);
        } else if (type == 'onAudioDownloadFail') {
          onAudioDownloadFail(result);
        } else if (type == 'onPeerMessageFailure') {
          onPeerMessageFailure(result);
        } else if (type == 'onAudioUploadSuccess') {
          String url = ValueUtil.toStr(data['URL']);
          onAudioUploadSuccess(result, url);
        } else if (type == 'onAudioUploadFail') {
          onAudioUploadFail(result);
        } else if (type == 'onImageUploadFail') {
          onImageUploadFail(result);
        } else if (type == 'onVideoUploadSuccess') {
          String url = ValueUtil.toStr(data['URL']);
          String thumbnailURL = ValueUtil.toStr(data['thumbnailURL']);
          onVideoUploadSuccess(result, url, thumbnailURL);
        } else if (type == 'onVideoUploadFail') {
          onVideoUploadFail(result);
        } else {
          logger.d(result);
        }
      } else {
        logger.d(response.message);
      }
    });
  }

  //TCPConnectionObserver
  onConnectState(var result) {
    int state = ValueUtil.toInt(result);
  }

  /// PeerMessageObserver
  onPeerSecretMessage(Map result) {
    Message message = Message.fromMap(result);
    if (message.sender != params.peerUID || message.receiver != params.currentUID) {
      return;
    }
    messages.insert(0, message);
    notifyListeners();
  }

  onPeerMessage(Map result) {
    Message message = Message.fromMap(result);
    if (message.sender != params.peerUID || message.receiver != params.currentUID) {
      return;
    }
    messages.insert(0, message);
    notifyListeners();
  }

  onPeerMessageACK(Map result, int error) {
    IMMessage im = IMMessage.fromMap(result);
    int msgLocalID = im.msgLocalID;
    String uid = im.receiver;
    if (uid != params.peerUID) {
      return;
    }
    if (error == MSG_ACK_SUCCESS) {
    } else {}
  }

  onPeerMessageFailure(Map result) {
    // IMMessage
  }

  /// OutboxObserver
  onImageUploadSuccess(Map result, String url) {
    ///IMessage
  }
  onAudioUploadSuccess(Map result, String url) {
    /// IMessage
  }
  onAudioUploadFail(Map result) {
    //IMessage
  }
  onImageUploadFail(Map result) {
    // IMessage
  }
  onVideoUploadSuccess(Map result, url, thumbnailURL) {}
  onVideoUploadFail(Map result) {}

  /// AudioDownloaderObserver
  onAudioDownloadSuccess(Map result) {
    // IMessage
  }
  onAudioDownloadFail(Map result) {
    //IMessage
  }
}
