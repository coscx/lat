import 'package:flt_im_plugin/flt_im_plugin.dart';
import 'package:flt_im_plugin/value_util.dart';
import 'package:flt_im_plugin_example/logger.dart';
import 'package:flutter/cupertino.dart';
import 'package:oktoast/oktoast.dart';

class IndexViewModel extends ChangeNotifier {
  String tfSender;
  String tfReceiver;

  login({void Function() success}) async {
    if (tfSender == null || tfSender.length == 0) {
      showToast('发送用户id 必须填写');
      return;
    }
    final res = await FltImPlugin().login(uid: tfSender);
    logger.d(res);
    int code = ValueUtil.toInt(res['code']);
    if (code == 0) {
      success?.call();
      tfSender = null;
      tfReceiver = null;
      notifyListeners();
    } else {
      String message = ValueUtil.toStr(res['message']);
      showToast(message);
    }
  }
}
