import 'package:flt_im_plugin/flt_im_plugin.dart';
import 'package:flt_im_plugin/value_util.dart';
import 'package:flt_im_plugin_example/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:oktoast/oktoast.dart';

class IndexViewModel extends ChangeNotifier {
  late String tfSender;
  late String tfReceiver;

  login({required void Function() success}) async {
    if (tfSender == null || tfSender.length == 0) {
      showToast('发送用户id 必须填写');
      return;
    }
    final res = await FltImPlugin().login(uid: tfSender, token: '');
    logger.d(res);
    int code = ValueUtil.toInt(res?['code']);
    if (code == 0) {
      success?.call();
      tfSender = "";
      tfReceiver = "";
      notifyListeners();
    } else {
      String message = ValueUtil.toStr(res?['message']);
      showToast(message);
    }
  }
}
