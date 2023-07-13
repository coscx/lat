import 'package:flt_im_plugin_example/logger.dart';
import 'package:flutter/material.dart';
import 'package:flt_im_plugin/conversion.dart';
import 'package:flt_im_plugin/flt_im_plugin.dart';
import 'package:flt_im_plugin/value_util.dart';
import 'package:oktoast/oktoast.dart';
import 'response.dart';

class MessageListViewModel extends ChangeNotifier {
  List<Conversion> conversions = [];
  FltImPlugin im = FltImPlugin();

  late String tfSender;

  MessageListViewModel(Map params) {
    tfSender = ValueUtil.toStr(params['currentUID']);
    listenNative();
    loadConversions();
  }

  loadConversions() async {
    Map? response = await im.getConversations();
    logger.d(response);
    conversions = ValueUtil.toArr(response?["data"]).map((e) => Conversion.fromMap(ValueUtil.toMap(e))).toList();
    notifyListeners();
  }

  deleteConversion(String cid) async {
    Map? res = await im.deleteConversation(rowid:"0",cid: cid);
    conversions.removeWhere((element) => element.cid == cid);
    notifyListeners();
  }

  listenNative() {
    im.onBroadcast.listen((event) {
      NativeResponse response = NativeResponse.fromMap(event);
      Map data = response.data;
      String type = ValueUtil.toStr(data['type']);
      var result = data['result'];
      if (response.code == 0) {
        if (type == 'onPeerMessageACK') {
          int error = ValueUtil.toInt(data['error']);
        } else if (type == 'onNewMessage') {
          // 有新的消息
          loadConversions();
        } else if (type == 'onSystemMessage') {
          loadConversions();
        } else if (type == 'onPeerMessageACK') {
          loadConversions();
        } else {
          logger.d(result);
        }
      } else {
        logger.d(response.message);
      }
    });
  }

  addConversion(String receiverId, BuildContext context) {
    if (receiverId == null || receiverId.length == 0) {
      showToast('接收用户id 必须填写');
      return;
    }
    Navigator.of(context).pushNamed('peer_page', arguments: {
      'currentUID': tfSender,
      'peerUID': receiverId,
    });
  }
}
